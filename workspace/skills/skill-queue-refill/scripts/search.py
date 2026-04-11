#!/usr/bin/env python3
"""
search.py - Discover Agent Skills on GitHub -> discovery_queue

Pure deterministic script. No AI/LLM involved.

Strategy:
- Run 3 code searches x 2 passes (newest + random backlog page)
- Deduplicate ALL hits in-memory by html_url BEFORE any DB or quality checks
- Batch pre-check DB to skip already-known URLs without API calls
- Group results by repo, apply quality filters
- Per file: parse frontmatter, quality gate
- Queue passing skills as 'pending'

Usage:
  python3 scripts/search.py
  python3 scripts/search.py --dry-run
  python3 scripts/search.py --max 50
"""

import os, re, sys, json, time, random, argparse
from pathlib import Path
from collections import defaultdict

from github import GitHubClient, raw_url
from db import connect, bulk_known_urls, repo_pending_count, insert_row

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

MAX_EVALUATE       = 50
TARGET_PENDING     = 20
MIN_REPO_STARS     = 10
MAX_HITS_PER_REPO  = 10
MAX_SKILLS_PER_REPO = 5
MIN_BODY_CHARS     = 300

SKIP_NAMES = {"my-skill", "skill-name", "example-skill", "todo", "template",
              "your-skill-name", "placeholder", "new-skill", "untitled"}

# Query pool — all target skill PUBLISHERS (regular dirs), never consumers
# (dotfile dirs like .claude/skills/ are filtered out by has_dotfile_path).
# Each run picks 3 queries via daily rotation for variety.
QUERY_POOL = [
    'filename:SKILL.md in:path skills "name:" "description:"',
    'filename:SKILL.md language:Markdown "name:" "description:"',
    'filename:SKILL.md in:path skills',
    'filename:SKILL.md "user-invocable" "description:"',
    'filename:SKILL.md "metadata" "description:"',
    'filename:SKILL.md "## Run" "name:" "description:"',
    'filename:SKILL.md language:Markdown in:path skills',
    'filename:SKILL.md "exec" "name:" "description:"',
]
QUERIES_PER_RUN = 3


# ---------------------------------------------------------------------------
# Filters
# ---------------------------------------------------------------------------

def has_dotfile_path(hits: list[dict]) -> bool:
    """True if ANY hit is under a dotfile directory.
    Dotfile paths (.claude/skills/, .openclaw/skills/, etc.) mean someone
    INSTALLED a skill in their project — they're consumers, not publishers.
    Skill publishers use regular directories (e.g. skills/my-skill/SKILL.md).
    """
    for hit in hits:
        parts = hit["path"].split("/")
        if any(p.startswith(".") for p in parts[:-1]):
            return True
    return False


def parse_frontmatter(content: str) -> tuple[dict, str]:
    """Parse YAML frontmatter and body. Returns (fm_dict, body_str)."""
    if not content.startswith("---"):
        return {}, content
    end = content.find("\n---", 3)
    if end == -1:
        return {}, content
    fm_text = content[3:end].strip()
    body = content[end + 4:].strip()

    fm: dict = {}
    current_key: str | None = None
    current_val: list[str] = []

    for line in fm_text.splitlines():
        if re.match(r'^[a-zA-Z_]+\s*:', line):
            if current_key:
                fm[current_key] = " ".join(current_val).strip()
            parts = line.split(":", 1)
            current_key = parts[0].strip()
            val = parts[1].strip() if len(parts) > 1 else ""
            current_val = [val] if val and val not in (">-", ">", "|", "") else []
        elif current_key and line.startswith("  "):
            current_val.append(line.strip())

    if current_key:
        fm[current_key] = " ".join(current_val).strip()

    return fm, body


def skill_quality_gate(fm: dict, body: str) -> tuple[bool, str]:
    """Quality gate for individual SKILL.md content."""
    name = fm.get("name", "").strip()
    description = fm.get("description", "").strip()

    if not name:
        return False, "no name in frontmatter"
    if not description:
        return False, "no description in frontmatter"
    if name.lower() in SKIP_NAMES:
        return False, f"placeholder name: {name}"
    if "TODO" in name or "TODO" in description:
        return False, "contains TODO placeholder"
    if len(description) < 80:
        return False, f"description too short ({len(description)} chars)"
    if len(body.strip()) < MIN_BODY_CHARS:
        return False, f"skill body too short ({len(body.strip())} chars)"
    if re.match(r'^(my|your|the|a|an)[-_\s]', name.lower()):
        return False, f"generic template name: {name}"

    return True, "ok"


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="Discover Agent Skills — pure script, no LLM")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--max", type=int, default=MAX_EVALUATE)
    parser.add_argument("--quiet", action="store_true", help="Suppress verbose output; print only final summary JSON")
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

    def progress(msg):
        print(msg, file=sys.stderr, flush=True)

    evaluated = known = pending_added = skipped_added = 0

    try:
        progress("skill_search: starting GitHub queries...")

        # -------------------------------------------------------------------
        # Step 1: Pick queries via rotation + collect hits
        # -------------------------------------------------------------------
        all_hits: dict[str, dict] = {}

        # Rotate: pick QUERIES_PER_RUN queries from the pool based on
        # day + hour so consecutive hourly runs use different queries
        now = time.localtime()
        rotation_seed = now.tm_yday * 24 + now.tm_hour
        queries = [
            QUERY_POOL[(rotation_seed + i) % len(QUERY_POOL)]
            for i in range(QUERIES_PER_RUN)
        ]
        # Deterministic backlog page per query (spread across 1-10)
        def backlog_page_for(qi: int) -> int:
            return (rotation_seed + qi * 3) % 10 + 1

        if not args.quiet:
            print(f"\nRotation seed: {rotation_seed} (day {now.tm_yday}, hour {now.tm_hour})")

        n = len(queries)
        for i, query in enumerate(queries, 1):
            if not args.quiet:
                print(f"\n[{i}a/{n}] {query} (newest)")
            else:
                progress(f"skill_search: query {i}a/{n}...")
            for h in gh.code_search(query, sort="indexed", order="desc", page=1):
                all_hits[h["html_url"]] = h
            if not args.quiet:
                print(f"  {len(all_hits)} unique hits so far")
            time.sleep(2)

            bp = backlog_page_for(i)
            if not args.quiet:
                print(f"[{i}b/{n}] {query} (backlog page {bp})")
            else:
                progress(f"skill_search: query {i}b/{n} ({len(all_hits)} hits)...")
            for h in gh.code_search(query, sort="indexed", order="asc", page=bp):
                all_hits.setdefault(h["html_url"], h)
            if not args.quiet:
                print(f"  {len(all_hits)} unique hits so far")
            time.sleep(2)

        if not args.quiet:
            print(f"\nTotal unique hits after all queries: {len(all_hits)}")
        else:
            progress(f"skill_search: {len(all_hits)} hits, filtering repos...")

        if gh.remaining is not None and not args.quiet:
            print(f"GitHub API remaining: {gh.remaining}")

        # -------------------------------------------------------------------
        # Step 2: Group by repo, apply repo-level filters
        # -------------------------------------------------------------------
        by_repo: dict[str, list[dict]] = defaultdict(list)
        for hit in all_hits.values():
            by_repo[hit["repository"]["full_name"]].append(hit)

        if not args.quiet:
            print(f"\n{len(by_repo)} unique repos in results")

        viable_repos: dict[str, list[dict]] = {}
        skipped_repos = {"dotfile": 0, "aggregator": 0}

        for repo_full_name, hits in by_repo.items():
            if has_dotfile_path(hits):
                skipped_repos["dotfile"] += 1
                continue
            if len(hits) > MAX_HITS_PER_REPO:
                skipped_repos["aggregator"] += 1
                continue
            viable_repos[repo_full_name] = hits

        if not args.quiet:
            print(f"{len(viable_repos)} viable repos after filters")
            print(f"  Skipped — dotfile repos: {skipped_repos['dotfile']}, "
                  f"aggregators: {skipped_repos['aggregator']}")

        # -------------------------------------------------------------------
        # Step 3: Build candidate list + batch DB pre-check
        # -------------------------------------------------------------------
        repo_list = list(viable_repos.items())
        random.shuffle(repo_list)

        candidates: list[dict] = []
        for _, hits in repo_list:
            candidates.extend(hits[:MAX_SKILLS_PER_REPO])
        random.shuffle(candidates)
        candidates = candidates[:args.max]

        # Build candidate source URLs using "main" as default branch (corrected later with repo meta)
        candidate_urls = [
            raw_url(h["repository"]["full_name"].split("/")[0],
                    h["repository"]["full_name"].split("/")[1],
                    h["path"])
            for h in candidates
        ]
        known_urls = bulk_known_urls(cur, candidate_urls)

        staleness = len(known_urls) / len(candidate_urls) if candidate_urls else 0

        if not args.quiet:
            print(f"\nEvaluating up to {len(candidates)} skills "
                  f"({len(known_urls)} already known, staleness: {staleness:.0%}, "
                  f"target: {TARGET_PENDING} pending)\n")
        else:
            progress(f"skill_search: evaluating {len(candidates)} candidates "
                     f"({len(known_urls)} pre-filtered, {staleness:.0%} stale)...")

        # -------------------------------------------------------------------
        # Step 4: Evaluate candidates
        # -------------------------------------------------------------------
        repo_meta_cache: dict[str, dict | None] = {}

        for hit in candidates:
            if pending_added >= TARGET_PENDING:
                if not args.quiet:
                    print(f"Reached target ({TARGET_PENDING}). Stopping.")
                break

            repo_full_name = hit["repository"]["full_name"]
            skill_path = hit["path"]
            owner, repo_name = repo_full_name.split("/", 1)
            evaluated += 1

            # Fetch repo meta (cached per repo)
            if repo_full_name not in repo_meta_cache:
                repo_meta_cache[repo_full_name] = gh.fetch_repo(owner, repo_name)
                time.sleep(0.3)
            repo_meta = repo_meta_cache[repo_full_name]

            stars = repo_meta.get("stargazers_count", 0) if repo_meta else 0
            default_branch = repo_meta.get("default_branch", "main") if repo_meta else "main"
            source_url = raw_url(owner, repo_name, skill_path, default_branch)

            if not args.quiet:
                print(f"  [{evaluated}] {repo_full_name}/{skill_path} ({stars}★)")

            # Pre-check: already in DB (from batch query)
            if source_url in known_urls:
                known += 1
                if not args.quiet:
                    print(f"    = known")
                continue

            if stars < MIN_REPO_STARS:
                skipped_added += 1
                if not args.quiet:
                    print(f"    ✗ skipped: {stars} stars < {MIN_REPO_STARS} minimum")
                if not args.dry_run:
                    insert_row(cur, source_url, repo_full_name, skill_path,
                               repo_meta, {}, "skipped", f"low stars: {stars}")
                continue

            already_queued = repo_pending_count(cur, repo_full_name)
            if already_queued >= MAX_SKILLS_PER_REPO:
                known += 1
                if not args.quiet:
                    print(f"    = repo cap reached ({already_queued} already queued)")
                continue

            content = gh.fetch_file(owner, repo_name, skill_path, default_branch)
            time.sleep(0.3)
            if not content:
                skipped_added += 1
                if not args.quiet:
                    print(f"    ✗ skipped: couldn't fetch content")
                if not args.dry_run:
                    insert_row(cur, source_url, repo_full_name, skill_path,
                               repo_meta, {}, "skipped", "could not fetch SKILL.md")
                continue

            fm, body = parse_frontmatter(content)
            passes, reason = skill_quality_gate(fm, body)

            if args.dry_run:
                if not args.quiet:
                    print(f"    [dry-run] {'PASS' if passes else f'SKIP ({reason})'} | name:{fm.get('name','?')}")
                pending_added += passes
                skipped_added += not passes
                continue

            if passes:
                insert_row(cur, source_url, repo_full_name, skill_path, repo_meta, fm, "pending")
                pending_added += 1
                if not args.quiet:
                    print(f"    ✓ queued: {fm.get('name','?')}")
            else:
                insert_row(cur, source_url, repo_full_name, skill_path, repo_meta, fm, "skipped", reason)
                skipped_added += 1
                if not args.quiet:
                    print(f"    ✗ skipped: {reason}")
    finally:
        conn.close()

    if args.quiet:
        result = json.dumps({
            "pending_added": pending_added,
            "skipped": skipped_added,
            "already_known": known,
            "evaluated": evaluated,
            "staleness": round(staleness, 2),
        })
        print(result, flush=True)
    else:
        print(f"""
Done.
  Evaluated:     {evaluated}
  Already known: {known}
  Staleness:     {staleness:.0%}
  → Pending:     {pending_added}
  → Skipped:     {skipped_added}
""")


if __name__ == "__main__":
    main()
