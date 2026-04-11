#!/usr/bin/env python3
"""
save.py - Write enriched skill data to DB.

Input JSON (array or single object):
{
  // From fetch.py (pass through unchanged):
  "queue_id": "uuid",
  "source_url": "https://raw.githubusercontent.com/...",
  "repo_source_url": "https://github.com/owner/repo",
  "owner": "owner",
  "repo_name": "repo",
  "repo_stars": 42,
  "repo_description": "...",
  "repo_banner_url": "...",
  "repo_icon_url": "...",
  "skill_path": "skills/my-skill/SKILL.md",
  "skill_md_url": "https://raw.githubusercontent.com/...",
  "github_browse_url": "https://github.com/.../blob/main/...",

  // Agent-written fields (required):
  "name": "skill-identifier",
  "slug": "url-safe-slug",
  "display_name": "Human Readable Name",
  "short_description": "max 160 chars",
  "long_description": "markdown, 200-400 words",
  "tags": ["tag1", "tag2"],
  "triggers": ["keyword1", "keyword2"],

  // Agent-written fields (optional):
  "repo_display_name": "override repo name if needed",
  "repo_slug": "override repo slug if needed"
}

Usage:
  python3 scripts/save.py --file /tmp/skills_enriched.json
  cat data.json | python3 scripts/save.py
"""

import os, re, sys, json, argparse
from pathlib import Path
import psycopg2, psycopg2.extras

# Auto-load .env from skill root (parent of scripts/)
_env_file = Path(__file__).resolve().parent.parent / ".env"
if _env_file.exists():
    for line in _env_file.read_text().splitlines():
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            key, _, val = line.partition("=")
            os.environ.setdefault(key.strip(), val.strip())

DB_URL = os.environ.get("DATABASE_URL")


def slugify(text: str) -> str:
    s = text.lower().strip()
    s = re.sub(r'[^a-z0-9]+', '-', s)
    return s.strip('-')[:80]


def upsert_skill_repo(cur, data: dict) -> str:
    """Upsert skill_repos row, return repo_id."""
    repo_source_url = data["repo_source_url"]
    owner_slug = slugify(data.get("owner", ""))
    repo_name_slug = slugify(data.get("repo_name", data["owner"]))
    # Always use owner-prefixed slug to avoid collisions across different owners.
    # Agent can override with repo_slug only if it already includes the owner.
    explicit = data.get("repo_slug", "")
    if explicit and owner_slug in explicit:
        repo_slug = slugify(explicit)
    else:
        repo_slug = f"{owner_slug}-{repo_name_slug}" if owner_slug not in repo_name_slug else repo_name_slug
    repo_name = data.get("repo_display_name") or data.get("repo_name", data["owner"])

    cur.execute(
        """
        INSERT INTO skill_repos (name, slug, description, github_url, owner,
            icon_url, banner_url, github_stars, source_url, status,
            created_at, updated_at)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, 'approved', now(), now())
        ON CONFLICT (source_url) DO UPDATE SET
            name         = EXCLUDED.name,
            description  = COALESCE(EXCLUDED.description, skill_repos.description),
            github_stars = EXCLUDED.github_stars,
            icon_url     = COALESCE(EXCLUDED.icon_url, skill_repos.icon_url),
            banner_url   = COALESCE(EXCLUDED.banner_url, skill_repos.banner_url),
            updated_at   = now()
        RETURNING id
        """,
        (
            repo_name,
            repo_slug,
            data.get("repo_description", ""),
            data["repo_source_url"],
            data["owner"],
            # Derive icon from owner if agent didn't pass it through
            data.get("repo_icon_url") or f"https://github.com/{data.get('owner','unknown')}.png?size=128",
            data.get("repo_banner_url"),
            data.get("repo_stars", 0),
            repo_source_url,
        ),
    )
    return cur.fetchone()[0]


def upsert_skill(cur, data: dict, repo_id: str) -> str:
    """Upsert agent_skills row, return skill id."""
    slug = slugify(data.get("slug") or data.get("name", ""))
    # Derive skill icon from repo owner avatar (same as repo icon)
    skill_icon = data.get("repo_icon_url") or f"https://github.com/{data.get('owner', 'unknown')}.png?size=128"

    cur.execute(
        """
        INSERT INTO agent_skills (
            repo_id, name, slug, display_name, short_description, long_description,
            author, author_url, github_url, source_path, skill_md_url, source_url,
            icon_url, compatible_agents, triggers, tags, status,
            created_at, updated_at, published_at
        ) VALUES (
            %(repo_id)s, %(name)s, %(slug)s, %(display_name)s,
            %(short_description)s, %(long_description)s,
            %(author)s, %(author_url)s, %(github_url)s,
            %(source_path)s, %(skill_md_url)s, %(source_url)s,
            %(icon_url)s, '{}', %(triggers)s, %(tags)s, 'approved',
            now(), now(), now()
        )
        ON CONFLICT (slug) DO UPDATE SET
            display_name      = EXCLUDED.display_name,
            short_description = EXCLUDED.short_description,
            long_description  = EXCLUDED.long_description,
            tags              = EXCLUDED.tags,
            triggers          = EXCLUDED.triggers,
            repo_id           = EXCLUDED.repo_id,
            icon_url          = COALESCE(EXCLUDED.icon_url, agent_skills.icon_url),
            updated_at        = now()
        RETURNING id
        """,
        {
            "repo_id": repo_id,
            "name": data.get("name", slug),
            "slug": slug,
            "display_name": data.get("display_name", slug.replace("-", " ").title()),
            "short_description": str(data.get("short_description", ""))[:160],
            "long_description": data.get("long_description", ""),
            "author": data.get("owner", ""),
            "author_url": data.get("repo_source_url", ""),
            "github_url": data.get("github_browse_url", ""),  # browse URL to the SKILL.md file
            "source_path": data.get("skill_path", ""),
            "skill_md_url": data.get("github_browse_url", ""),  # browse URL for user-facing link
            "source_url": data.get("source_url", ""),  # raw file URL = dedup key
            "icon_url": skill_icon,
            "triggers": data.get("triggers", []),
            "tags": data.get("tags", []),
        },
    )
    return cur.fetchone()[0]


def update_skill_count(cur, repo_id: str):
    cur.execute(
        """
        UPDATE skill_repos SET skill_count = (
            SELECT count(*) FROM agent_skills
            WHERE repo_id = %s AND deleted_at IS NULL
        ) WHERE id = %s
        """,
        (repo_id, repo_id),
    )


def mark_done(cur, queue_id: str):
    cur.execute(
        "UPDATE discovery_queue SET status='done', processed_at=now(), error=NULL WHERE id=%s",
        (queue_id,),
    )


def mark_failed(cur, queue_id: str, error: str):
    cur.execute(
        "UPDATE discovery_queue SET status='failed', processed_at=now(), error=%s WHERE id=%s",
        (str(error)[:500], queue_id),
    )


def save_one(conn, data: dict) -> dict:
    required = ["queue_id", "source_url", "repo_source_url", "owner",
                "name", "slug", "display_name", "short_description", "long_description"]
    missing = [f for f in required if not data.get(f)]
    if missing:
        return {"ok": False, "error": f"Missing: {missing}"}

    try:
        with conn:
            cur = conn.cursor()
            repo_id = upsert_skill_repo(cur, data)
            skill_id = upsert_skill(cur, data, repo_id)
            update_skill_count(cur, repo_id)
            mark_done(cur, data["queue_id"])
        return {"ok": True, "skill_id": str(skill_id), "repo_id": str(repo_id), "slug": data["slug"]}
    except Exception as e:
        with conn:
            cur = conn.cursor()
            mark_failed(cur, data["queue_id"], str(e))
        return {"ok": False, "error": str(e)}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--file", help="JSON file (default: stdin)")
    args = parser.parse_args()

    if not DB_URL:
        print("ERROR: DATABASE_URL not set", file=sys.stderr)
        sys.exit(1)

    payload = json.load(open(args.file) if args.file else sys.stdin)
    items = payload if isinstance(payload, list) else [payload]

    conn = psycopg2.connect(DB_URL, sslmode="require")
    psycopg2.extras.register_uuid()

    results = []
    for item in items:
        result = save_one(conn, item)
        status = "✓" if result["ok"] else "✗"
        msg = result.get("slug") or result.get("error")
        print(f"  {status} {item.get('repo_full_name','?')} / {item.get('name','?')} → {msg}")
        results.append(result)

    conn.close()
    print(json.dumps(results, indent=2))


if __name__ == "__main__":
    main()
