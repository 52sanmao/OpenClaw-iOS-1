#!/usr/bin/env python3
"""
fetch.py — Pick 1 unaudited skill, download SKILL.md + any scripts/, output JSON for agent.

Usage: python3 fetch.py
Output: /tmp/skill_audit_fetch.json
"""

import json, os, sys, requests, base64
from pathlib import Path
import psycopg2

# Auto-load .env from skill root (parent of scripts/)
_env_file = Path(__file__).resolve().parent.parent / ".env"
if _env_file.exists():
    for line in _env_file.read_text().splitlines():
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            key, _, val = line.partition("=")
            os.environ.setdefault(key.strip(), val.strip())

DB_URL = os.environ.get("DATABASE_URL")
GH_TOKEN = os.environ.get("GITHUB_TOKEN")

if not DB_URL:
    print("ERROR: DATABASE_URL not set", file=sys.stderr)
    sys.exit(1)

conn = psycopg2.connect(DB_URL)
try:
    cur = conn.cursor()

    # Pick 1 unaudited skill
    cur.execute("""
        SELECT s.id, s.slug, s.source_url, s.skill_md_url, s.github_url, s.source_path,
               s.name, s.display_name, s.short_description, s.tags
        FROM agent_skills s
        LEFT JOIN skill_audits a ON a.skill_id = s.id
        WHERE s.deleted_at IS NULL
          AND s.status != 'suspended'
          AND a.id IS NULL
        ORDER BY s.created_at ASC
        LIMIT 1
    """)
    row = cur.fetchone()
finally:
    conn.close()

if not row:
    print(json.dumps({"nothing_to_audit": True}))
    sys.exit(0)

skill_id, slug, source_url, skill_md_url, github_url, source_path, name, display_name, short_desc, tags = row

headers = {}
if GH_TOKEN:
    headers["Authorization"] = f"token {GH_TOKEN}"

def fetch_raw(url):
    r = requests.get(url, headers=headers, timeout=15)
    if r.status_code == 200:
        return r.text
    return None

# Fetch SKILL.md — use source_url (raw content URL), not skill_md_url (HTML page)
raw_url = source_url or skill_md_url
skill_md_body = fetch_raw(raw_url) if raw_url else None

# Derive scripts/ base URL from source_path + source_url
scripts = {}
if source_url and source_path:
    # e.g. source_path = "skills/my-skill/SKILL.md"
    # scripts dir = "skills/my-skill/scripts/"
    skill_dir = "/".join(source_path.split("/")[:-1])  # strip SKILL.md
    # source_url is raw: https://raw.githubusercontent.com/owner/repo/branch/path/SKILL.md
    # GitHub API: https://api.github.com/repos/owner/repo/contents/path/scripts?ref=branch
    if "raw.githubusercontent.com" in source_url:
        parts = source_url.replace("https://raw.githubusercontent.com/", "").split("/")
        owner, repo, branch = parts[0], parts[1], parts[2]
        scripts_path = f"{skill_dir}/scripts" if skill_dir else "scripts"
        scripts_api = f"https://api.github.com/repos/{owner}/{repo}/contents/{scripts_path}?ref={branch}"
        r = requests.get(scripts_api, headers=headers, timeout=15)
        if r.status_code == 200:
            for f in r.json():
                if isinstance(f, dict) and f.get("type") == "file":
                    fname = f["name"]
                    download_url = f.get("download_url") or f.get("html_url")
                    content = fetch_raw(download_url) if download_url else None
                    if content:
                        scripts[fname] = content

result = {
    "skill_id": str(skill_id),
    "slug": slug,
    "name": name,
    "display_name": display_name,
    "short_description": short_desc,
    "tags": tags or [],
    "github_url": github_url,
    "source_path": source_path,
    "skill_md_url": skill_md_url,
    "source_url": source_url,
    "skill_md_body": skill_md_body,
    "scripts": scripts,  # dict: filename -> content
}

out = Path("/tmp/skill_audit_fetch.json")
out.write_text(json.dumps(result, indent=2))
print(f"Fetched skill: {slug} ({len(scripts)} scripts found)")
print(f"Output: {out}")
