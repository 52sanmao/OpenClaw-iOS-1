#!/usr/bin/env python3
"""
save.py — Write enriched app data to the database.

Called by the agent after it has written descriptions.
Reads enriched JSON from stdin or --file argument.

Input JSON shape (one object or array of objects):
{
  "queue_id": "uuid",
  "source_url": "https://github.com/owner/repo",
  "repo_full_name": "owner/repo",
  "owner": "owner",
  "app_type": "mcp-app" | "mcp-server",
  "npm_package": "...",
  "banner_url": "...",
  "screenshot_urls": [...],
  "icon_url": "...",
  "github_stars": 42,
  "github_description": "...",
  "pushed_at": "2026-04-01T...",
  "npm_meta": { "homepage": "..." },

  // Agent-written fields (required):
  "name": "Display Name",
  "slug": "url-safe-slug",
  "short_description": "...",
  "description": "...",
  "keywords": [...],
  "supported_hosts": [...],
  "category_slug": "..."
}

Usage:
  echo '{...}' | python3 scripts/save.py
  python3 scripts/save.py --file enriched.json
  cat results.json | python3 scripts/save.py
"""

import os
import re
import sys
import json
import argparse
from pathlib import Path
import psycopg2
import psycopg2.extras

# Auto-load .env from skill root (parent of scripts/)
_env_file = Path(__file__).resolve().parent.parent / ".env"
if _env_file.exists():
    for line in _env_file.read_text().splitlines():
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            key, _, val = line.partition("=")
            os.environ.setdefault(key.strip(), val.strip())

DB_URL = os.environ.get("DATABASE_URL")

CATEGORY_SLUGS = {
    "data-visualization", "forms-configuration", "media-viewers",
    "monitoring-dashboards", "productivity", "developer-tools",
}
VALID_HOSTS = {
    "claude-desktop", "claude-ai", "vscode-copilot", "cursor", "goose",
    "codex", "gemini-cli", "chatgpt", "mcpjam", "postman",
    "librechat", "zed", "windsurf"
}


def slugify(text: str) -> str:
    s = text.lower().strip()
    s = re.sub(r'[^a-z0-9]+', '-', s)
    return s.strip('-')[:80]


def get_or_create_org(cur, owner: str) -> str:
    slug = slugify(owner)
    cur.execute(
        """
        INSERT INTO organizations (name, slug)
        VALUES (%s, %s)
        ON CONFLICT (slug) DO UPDATE SET name = EXCLUDED.name
        RETURNING id
        """,
        (owner, slug),
    )
    return cur.fetchone()[0]


def get_category_id(cur, slug: str) -> str | None:
    cur.execute("SELECT id FROM categories WHERE slug = %s", (slug,))
    row = cur.fetchone()
    return row[0] if row else None


def save_one(conn, data: dict) -> dict:
    """Save one enriched app. Returns result dict."""
    # Validate required agent-written fields
    # Note: supported_hosts is validated separately (empty list is allowed — gets a default)
    required = ["name", "slug", "short_description", "description", "keywords",
                "category_slug", "queue_id", "install_command",
                "pricing", "source_url"]
    missing = [f for f in required if not data.get(f)]
    if missing:
        return {"ok": False, "error": f"Missing required fields: {missing}"}

    # Sanitise
    slug = re.sub(r'[^a-z0-9]+', '-', data["slug"].lower()).strip('-')[:80]
    short_desc = str(data["short_description"])[:160]
    category_slug = data["category_slug"] if data["category_slug"] in CATEGORY_SLUGS else "developer-tools"
    # Filter to valid hosts; fall back to ["claude"] if agent returned empty/invalid list
    supported_hosts = [h for h in data.get("supported_hosts", []) if h in VALID_HOSTS]
    if not supported_hosts:
        supported_hosts = ["claude"]
    keywords = [k for k in data.get("keywords", []) if isinstance(k, str)][:10]
    pricing = data.get("pricing", "free")
    if pricing not in {"free", "freemium", "paid", "subscription"}:
        pricing = "free"
    # type and has_ui driven by mode stored in queue metadata
    queue_mode = data.get("queue_mode", "apps")  # fetch.py passes this from metadata
    app_type = "mcp-app" if queue_mode == "apps" else "mcp-server"
    has_ui   = queue_mode == "apps"
    install_command = data.get("install_command") or (f"npx {data['npm_package']}" if data.get("npm_package") else None)

    npm_meta = data.get("npm_meta") or {}
    agent_meta = data.get("metadata", {}) or {}
    app_metadata = json.dumps({
        "supportedHosts": supported_hosts,
        "githubStars": data.get("github_stars", 0),
        "githubLastCommit": data.get("pushed_at", ""),
        "demoUrl": agent_meta.get("demoUrl") or npm_meta.get("homepage", ""),
        "documentationUrl": agent_meta.get("documentationUrl", ""),
        "mcpCapabilities": agent_meta.get("mcpCapabilities", []),
        "installInstructions": agent_meta.get("installInstructions", {}),
    })

    with conn:
        cur = conn.cursor()

        publisher_id = get_or_create_org(cur, data["owner"])

        cur.execute(
            """
            INSERT INTO apps (
                type, has_ui, publisher_id, name, slug, short_description, description,
                icon_url, banner_url, github_url, npm_package, install_command,
                status, pricing, keywords, metadata, source_url,
                published_at, created_at, updated_at
            ) VALUES (
                %(type)s, %(has_ui)s, %(publisher_id)s, %(name)s, %(slug)s,
                %(short_description)s, %(description)s,
                %(icon_url)s, %(banner_url)s, %(github_url)s,
                %(npm_package)s, %(install_command)s,
                'approved', %(pricing)s,
                %(keywords)s, %(metadata)s::jsonb, %(source_url)s,
                now(), now(), now()
            )
            ON CONFLICT (slug) DO UPDATE SET
                short_description = EXCLUDED.short_description,
                description       = EXCLUDED.description,
                has_ui            = EXCLUDED.has_ui,
                icon_url          = COALESCE(EXCLUDED.icon_url, apps.icon_url),
                banner_url        = COALESCE(EXCLUDED.banner_url, apps.banner_url),
                install_command   = EXCLUDED.install_command,
                keywords          = EXCLUDED.keywords,
                metadata          = EXCLUDED.metadata::jsonb,
                pricing           = EXCLUDED.pricing,
                updated_at        = now()
            RETURNING id
            """,
            {
                "type": app_type,
                "has_ui": has_ui,
                "publisher_id": publisher_id,
                "name": data["name"],
                "slug": slug,
                "short_description": short_desc,
                "description": data["description"],
                "icon_url": data.get("icon_url"),
                "banner_url": data.get("banner_url"),
                "github_url": data.get("source_url"),
                "npm_package": data.get("npm_package") or None,
                "install_command": install_command,
                "pricing": pricing,
                "keywords": keywords,
                "metadata": app_metadata,
                "source_url": data.get("source_url"),
            },
        )
        app_id = cur.fetchone()[0]

        # Screenshots — support alt_text and caption from agent
        for i, shot in enumerate(data.get("screenshot_urls", [])[:3]):
            if isinstance(shot, dict):
                url = shot.get("url", "")
                alt_text = shot.get("alt_text", "")
                caption = shot.get("caption", "")
            else:
                url = shot
                alt_text = ""
                caption = ""
            if url:
                cur.execute(
                    """INSERT INTO screenshots (app_id, url, alt_text, caption, display_order)
                       VALUES (%s, %s, %s, %s, %s) ON CONFLICT DO NOTHING""",
                    (app_id, url, alt_text, caption, i),
                )

        # Category
        cat_id = get_category_id(cur, category_slug)
        if cat_id:
            cur.execute(
                "INSERT INTO app_categories (app_id, category_id) VALUES (%s, %s) ON CONFLICT DO NOTHING",
                (app_id, cat_id),
            )

        # Mark queue done
        cur.execute(
            "UPDATE discovery_queue SET status='done', processed_at=now(), error=NULL WHERE id=%s",
            (data["queue_id"],),
        )

    return {"ok": True, "app_id": str(app_id), "slug": slug}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--file", help="JSON file to read (default: stdin)")
    args = parser.parse_args()

    if args.file:
        with open(args.file) as f:
            payload = json.load(f)
    else:
        payload = json.load(sys.stdin)

    if not DB_URL:
        print("ERROR: DATABASE_URL not set", file=sys.stderr)
        sys.exit(1)

    # Accept single object or array
    items = payload if isinstance(payload, list) else [payload]

    conn = psycopg2.connect(DB_URL, sslmode="require")
    psycopg2.extras.register_uuid()

    results = []
    try:
        for item in items:
            result = save_one(conn, item)
            results.append({**result, "repo": item.get("repo_full_name", "?")})
            status = "ok" if result["ok"] else "FAIL"
            msg = result.get("slug") or result.get("error")
            print(f"  {status} {item.get('repo_full_name', '?')} -> {msg}")
    finally:
        conn.close()

    print(json.dumps(results, indent=2))


if __name__ == "__main__":
    main()
