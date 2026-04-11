#!/usr/bin/env python3
"""
fetch.py - Claim pending skill queue items, deep-fetch content, output JSON.

Picks up to 2 pending items from discovery_queue (target_table='agent_skills'),
fetches SKILL.md + sibling files + repo README, outputs JSON for agent enrichment.

Usage:
  python3 scripts/fetch.py
  python3 scripts/fetch.py --limit 1
"""

import os, re, sys, json, time, base64, argparse
from pathlib import Path
import requests, psycopg2, psycopg2.extras

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
GH_HEADERS = {
    "Authorization": f"Bearer {GH_TOKEN}",
    "Accept": "application/vnd.github+json",
    "X-GitHub-Api-Version": "2022-11-28",
}


def gh_get(url: str) -> dict | None:
    for attempt in range(3):
        resp = requests.get(url, headers=GH_HEADERS, timeout=15)
        if resp.status_code == 404:
            return None
        if resp.status_code == 403:
            time.sleep(60)
            continue
        resp.raise_for_status()
        return resp.json()
    return None


def fetch_raw(owner: str, repo: str, path: str, branch: str) -> str | None:
    data = gh_get(f"https://api.github.com/repos/{owner}/{repo}/contents/{path}?ref={branch}")
    if data and data.get("encoding") == "base64":
        try:
            return base64.b64decode(data["content"]).decode("utf-8", errors="replace")
        except Exception:
            return None
    return None


def list_dir(owner: str, repo: str, path: str, branch: str) -> list[str]:
    """List filenames in a directory."""
    data = gh_get(f"https://api.github.com/repos/{owner}/{repo}/contents/{path}?ref={branch}")
    if not data or not isinstance(data, list):
        return []
    return [item["name"] for item in data]


def fetch_repo_readme(owner: str, repo: str, branch: str) -> str:
    """Fetch repo README content."""
    for name in ["README.md", "readme.md", "README.rst", "README"]:
        content = fetch_raw(owner, repo, name, branch)
        if content:
            return content
    return ""


def extract_images(readme: str) -> list[str]:
    urls = []
    for m in re.finditer(r'!\[.*?\]\((https?://[^\s)]+)\)', readme):
        urls.append(m.group(1))
    for m in re.finditer(r'<img[^>]+src=["\']([^"\']+)["\']', readme, re.IGNORECASE):
        u = m.group(1)
        if u.startswith('https://'):
            urls.append(u)
    # Only absolute https:// URLs — reject relative paths which 404 on the site
    return [
        u for u in urls
        if u.startswith('https://')
        and not any(x in u for x in ["shields.io", "badge", "img.shields"])
    ][:3]


def parse_frontmatter(content: str) -> tuple[dict, str]:
    if not content.startswith("---"):
        return {}, content
    end = content.find("\n---", 3)
    if end == -1:
        return {}, content
    fm_text = content[3:end].strip()
    body = content[end + 4:].strip()
    fm = {}
    current_key = None
    current_val = []
    for line in fm_text.splitlines():
        if re.match(r'^[a-zA-Z_]+:', line):
            if current_key:
                fm[current_key] = " ".join(current_val).strip()
            parts = line.split(":", 1)
            current_key = parts[0].strip()
            val = parts[1].strip() if len(parts) > 1 else ""
            current_val = [val] if val and val not in (">-", ">", "|") else []
        elif current_key and line.startswith("  "):
            current_val.append(line.strip())
    if current_key:
        fm[current_key] = " ".join(current_val).strip()
    return fm, body


def claim_pending(cur) -> dict | None:
    cur.execute(
        """
        UPDATE discovery_queue SET status = 'processing'
        WHERE id = (
            SELECT id FROM discovery_queue
            WHERE target_table = 'agent_skills' AND status = 'pending'
            ORDER BY (metadata->>'repo_stars')::int DESC NULLS LAST, discovered_at ASC
            LIMIT 1
            FOR UPDATE SKIP LOCKED
        )
        RETURNING id, source_url, repo_full_name, metadata
        """
    )
    row = cur.fetchone()
    if not row:
        return None
    return {"id": str(row[0]), "source_url": row[1], "repo_full_name": row[2], "metadata": row[3] or {}}


def fetch_skill_data(item: dict) -> dict:
    meta = item["metadata"]
    repo_full_name = item["repo_full_name"]
    skill_path = meta.get("skill_path", "SKILL.md")  # e.g. "skills/my-skill/SKILL.md"
    owner, repo_name = repo_full_name.split("/", 1)
    branch = meta.get("default_branch", "main")

    # Derive skill directory from skill_path
    skill_dir = "/".join(skill_path.split("/")[:-1])  # strip SKILL.md filename

    # Fetch SKILL.md
    skill_content = fetch_raw(owner, repo_name, skill_path, branch) or ""
    time.sleep(0.4)
    fm, body = parse_frontmatter(skill_content)

    # List sibling files (scripts/, references/ etc)
    sibling_files = []
    if skill_dir:
        sibling_files = list_dir(owner, repo_name, skill_dir, branch)
        time.sleep(0.3)

    has_scripts = "scripts" in sibling_files
    has_references = "references" in sibling_files

    # Fetch repo-level README for banner image
    repo_readme = fetch_repo_readme(owner, repo_name, branch)
    time.sleep(0.4)
    repo_images = extract_images(repo_readme)

    # Build raw skill URL and GitHub browse URL
    skill_md_url = f"https://raw.githubusercontent.com/{repo_full_name}/{branch}/{skill_path}"
    github_browse_url = f"https://github.com/{repo_full_name}/blob/{branch}/{skill_path}"

    return {
        "queue_id": item["id"],
        "source_url": item["source_url"],
        "repo_full_name": repo_full_name,
        "repo_source_url": f"https://github.com/{repo_full_name}",
        "owner": owner,
        "repo_name": repo_name,
        "branch": branch,
        "skill_path": skill_path,
        "skill_dir": skill_dir,
        "skill_md_url": skill_md_url,
        "github_browse_url": github_browse_url,
        # Frontmatter (raw — agent reads these as starting point)
        "fm_name": fm.get("name", ""),
        "fm_description": fm.get("description", ""),
        # Full content for agent to read
        "skill_md_body": body,
        "skill_md_full": skill_content,
        # Repo-level metadata
        "repo_stars": meta.get("repo_stars", 0),
        "repo_description": meta.get("repo_description", ""),
        "repo_topics": meta.get("repo_topics", []),
        "repo_banner_url": repo_images[0] if repo_images else None,
        "repo_icon_url": f"https://github.com/{owner}.png?size=128",
        # Structure signals
        "has_scripts": has_scripts,
        "has_references": has_references,
        "sibling_files": sibling_files,
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--limit", type=int, default=2)
    args = parser.parse_args()

    if not GH_TOKEN:
        print("ERROR: GITHUB_TOKEN not set", file=sys.stderr)
        sys.exit(1)
    if not DB_URL:
        print("ERROR: DATABASE_URL not set", file=sys.stderr)
        sys.exit(1)

    conn = psycopg2.connect(DB_URL, sslmode="require")
    psycopg2.extras.register_uuid()

    # Auto-recover stuck processing rows
    cur = conn.cursor()
    cur.execute(
        """
        UPDATE discovery_queue SET status = 'pending'
        WHERE status = 'processing'
          AND target_table = 'agent_skills'
          AND processed_at IS NULL
          AND discovered_at < now() - interval '30 minutes'
        """
    )
    recovered = cur.rowcount
    conn.commit()
    if recovered:
        print(f"[recovery] Reset {recovered} stuck processing rows", flush=True)

    results = []
    seen_ids = set()

    for _ in range(args.limit):
        cur = conn.cursor()
        item = claim_pending(cur)
        conn.commit()
        if not item or item["id"] in seen_ids:
            break
        seen_ids.add(item["id"])
        data = fetch_skill_data(item)
        results.append(data)
        time.sleep(1)

    conn.close()
    print(json.dumps(results, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
