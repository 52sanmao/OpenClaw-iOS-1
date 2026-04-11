#!/usr/bin/env python3
"""
search.py — MCP Discovery: GitHub search → quality gate → discovery_queue

Two passes per repo strategy:
  - "newest": pushed:>cursor_date (catch new repos)
  - "backlog": no date filter, random page (discover older repos)

Code searches use query rotation (pool of 11, pick 3 per run).

Usage:
  python3 scripts/search.py --mode apps
  python3 scripts/search.py --mode servers
  python3 scripts/search.py --dry-run
  python3 scripts/search.py --max 30
"""

import os, sys, json, time, random, argparse
from pathlib import Path

from github import GitHubClient
from db import connect, get_cursor, bulk_known_repos, insert_row
from gates import (fetch_project_manifest, quality_gate_apps, quality_gate_servers)

# Auto-load .env from skill root (parent of scripts/)
_env_file = Path(__file__).resolve().parent.parent / ".env"
if _env_file.exists():
    for line in _env_file.read_text().splitlines():
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            key, _, val = line.partition("=")
            os.environ.setdefault(key.strip(), val.strip())

DB_URL   = os.environ.get("DATABASE_URL")
GH_TOKEN = os.environ.get("GITHUB_TOKEN")

SKIP_REPOS = {"modelcontextprotocol/ext-apps", "modelcontextprotocol/servers",
              "modelcontextprotocol/python-sdk", "modelcontextprotocol/typescript-sdk",
              "mark3labs/mcp-go", "anthropics/anthropic-sdk-python"}
MAX_EVALUATE   = 50
TARGET_PENDING = 10

# ---------------------------------------------------------------------------
# Search strategies
# ---------------------------------------------------------------------------

APP_REPO_STRATEGIES = [
    "topic:mcp-app",
]

APP_CODE_POOL = [
    # High-signal: direct MCP Apps SDK patterns
    '"@modelcontextprotocol/ext-apps" filename:package.json',   # ~850 results
    '"resourceUri" "ui://"',                                     # ~1200 results
    '"@mcp-ui" filename:package.json',                           # ~340 results
    # Medium-signal
    '"ext-apps" filename:*.ts',
    '"mcp-ui/client" filename:package.json',
]
APP_CODE_PER_RUN = 3

SERVER_REPO_STRATEGIES = [
    "topic:mcp-server",
    "topic:model-context-protocol",
]

SERVER_CODE_POOL = [
    # TypeScript/Node
    '"@modelcontextprotocol/sdk" filename:package.json',
    '"McpServer" filename:*.ts',
    # Python
    '"fastmcp" filename:*.py',
    '"from mcp" filename:*.py',
    '"mcp" filename:pyproject.toml',
    # Go
    '"mcp-go" filename:go.mod',
    # Rust
    '"rmcp" filename:Cargo.toml',
    # Java/Kotlin
    '"io.modelcontextprotocol" filename:pom.xml',
    '"io.modelcontextprotocol" filename:build.gradle',
    # C#
    '"ModelContextProtocol" filename:*.csproj',
]
SERVER_CODE_PER_RUN = 3


def normalise(full_name: str) -> str:
    return full_name.lower().strip("/").split("?")[0]


def stub_repo(name: str) -> dict:
    """Create a minimal repo dict for code search results (no metadata yet)."""
    return {"full_name": name, "html_url": f"https://github.com/{name}",
            "fork": False, "archived": False, "stargazers_count": 0,
            "topics": [], "default_branch": "main", "description": "",
            "pushed_at": "", "name": name.split("/")[-1], "license": None}


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=["apps", "servers"], default="apps")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--max", type=int, default=MAX_EVALUATE)
    parser.add_argument("--quiet", action="store_true")
    args = parser.parse_args()

    if not GH_TOKEN:
        print("ERROR: GITHUB_TOKEN not set", file=sys.stderr)
        sys.exit(1)
    if not DB_URL:
        print("ERROR: DATABASE_URL not set", file=sys.stderr)
        sys.exit(1)

    gh = GitHubClient(GH_TOKEN)
    conn = connect(DB_URL)
    cur = conn.cursor()

    gate = quality_gate_apps if args.mode == "apps" else quality_gate_servers

    # Pick code search strategies via rotation
    now = time.localtime()
    rotation_seed = now.tm_yday * 24 + now.tm_hour

    if args.mode == "apps":
        repo_queries = APP_REPO_STRATEGIES
        code_pool = APP_CODE_POOL
        code_per_run = APP_CODE_PER_RUN
    else:
        repo_queries = SERVER_REPO_STRATEGIES
        code_pool = SERVER_CODE_POOL
        code_per_run = SERVER_CODE_PER_RUN

    code_picks = [
        code_pool[(rotation_seed + i) % len(code_pool)]
        for i in range(code_per_run)
    ]

    evaluated = known = pending_added = skipped_added = 0

    try:
        cursor_date = get_cursor(cur, args.mode)
        if not args.quiet:
            print(f"Mode: {args.mode} | Cursor: {cursor_date or 'first run'}")
            print(f"Code queries this run: {code_picks}")

        # -------------------------------------------------------------------
        # Step 1: Collect candidates
        # -------------------------------------------------------------------
        raw: dict[str, dict] = {}
        step = 0

        # Repo searches — two passes: newest (with cursor) + backlog (no cursor, random page)
        for query in repo_queries:
            # Pass A: newest — repos pushed after cursor date
            step += 1
            newest_q = f"{query} pushed:>{cursor_date}" if cursor_date else query
            if not args.quiet:
                print(f"\n[{step}] repo (newest): {newest_q[:70]}")
            for r in gh.search_repos(newest_q, sort="updated", order="desc"):
                raw[normalise(r["full_name"])] = r
            if not args.quiet:
                print(f"  {len(raw)} unique repos")
            time.sleep(1)

            # Pass B: backlog — all time, lower pages for variety (1-5 to avoid empty pages)
            step += 1
            backlog_page = (rotation_seed + step) % 5 + 1
            if not args.quiet:
                print(f"[{step}] repo (backlog page {backlog_page}): {query[:70]}")
            for r in gh.search_repos(query, sort="stars", order="desc", page=backlog_page):
                raw.setdefault(normalise(r["full_name"]), r)
            if not args.quiet:
                print(f"  {len(raw)} unique repos")
            time.sleep(1)

        # Code searches — rotated picks
        for query in code_picks:
            step += 1
            if not args.quiet:
                print(f"\n[{step}] code: {query[:70]}")
            for name in gh.search_code(query):
                key = normalise(name)
                if key not in raw:
                    raw[key] = stub_repo(name)
            if not args.quiet:
                print(f"  {len(raw)} unique repos")
            time.sleep(1)

        # Filter
        candidates = [
            r for key, r in raw.items()
            if key not in SKIP_REPOS and not r.get("fork") and not r.get("archived")
        ]
        if not args.quiet:
            print(f"\n{len(candidates)} candidates after filtering")

        # -------------------------------------------------------------------
        # Step 2: Batch DB pre-check
        # -------------------------------------------------------------------
        all_names = [r["full_name"] for r in candidates]
        known_repos = bulk_known_repos(cur, all_names)

        # -------------------------------------------------------------------
        # Step 3: Sample and evaluate
        # -------------------------------------------------------------------
        sample = random.sample(candidates, min(args.max, len(candidates)))
        if not args.quiet:
            print(f"Evaluating {len(sample)} ({len(known_repos)} pre-filtered, "
                  f"target: {TARGET_PENDING} pending)\n")

        for repo in sample:
            if pending_added >= TARGET_PENDING:
                if not args.quiet:
                    print(f"Reached target ({TARGET_PENDING}). Stopping.")
                break

            key = normalise(repo["full_name"])
            owner, repo_name = key.split("/", 1)
            evaluated += 1

            if key in known_repos:
                known += 1
                continue

            if not args.quiet:
                print(f"  [{evaluated}] {key} ({repo.get('stargazers_count', 0)}★)")

            # Hydrate stub repos from code search
            if not repo.get("pushed_at") and not args.dry_run:
                full = gh.fetch_repo(repo["full_name"])
                if full:
                    repo = full
                time.sleep(0.3)

            branch = repo.get("default_branch", "main")
            manifest = fetch_project_manifest(gh, owner, repo_name, branch)
            time.sleep(0.3)
            readme = (
                gh.fetch_file(owner, repo_name, "README.md", branch)
                or gh.fetch_file(owner, repo_name, "readme.md", branch)
                or ""
            )
            time.sleep(0.3)

            passes, reason = gate(repo, manifest, readme)

            if args.dry_run:
                if not args.quiet:
                    lang = f" [{manifest['kind'] or '?'}]"
                    print(f"    [dry-run] {'PASS' if passes else f'SKIP ({reason})'}{lang}")
                pending_added += passes
                skipped_added += not passes
                continue

            if passes:
                insert_row(cur, repo, "pending", args.mode)
                pending_added += 1
                if not args.quiet:
                    print(f"    ✓ pending [{manifest['kind'] or '?'}]")
            else:
                insert_row(cur, repo, "skipped", args.mode, reason)
                skipped_added += 1
                if not args.quiet:
                    print(f"    ✗ skipped: {reason}")
    finally:
        conn.close()

    if args.quiet:
        print(json.dumps({
            "mode": args.mode,
            "pending_added": pending_added,
            "skipped": skipped_added,
            "already_known": known,
            "evaluated": evaluated,
        }))
    else:
        print(f"""
Done.
  Evaluated:     {evaluated}
  Already known: {known}
  → Pending:     {pending_added}
  → Skipped:     {skipped_added}
""")


if __name__ == "__main__":
    main()
