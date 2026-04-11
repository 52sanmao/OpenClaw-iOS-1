#!/usr/bin/env python3
"""
news_save.py — save enriched news items to the DB.

Reads enriched JSON array from /tmp/news_enriched.json
Upserts to news_items (dedup by url), updates news_sources.last_fetched_at.

Usage:
    python3 news_save.py
"""

import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

import psycopg2
from psycopg2.extras import execute_values

# Auto-load .env from skill root (parent of scripts/)
_env_file = Path(__file__).resolve().parent.parent / ".env"
if _env_file.exists():
    for line in _env_file.read_text().splitlines():
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            key, _, val = line.partition("=")
            os.environ.setdefault(key.strip(), val.strip())

DATABASE_URL = os.environ.get("DATABASE_URL")

DB_URL = os.environ.get("DATABASE_URL")
ENRICHED_PATH = "/tmp/news_enriched.json"


def get_db():
    return psycopg2.connect(DATABASE_URL)


def main():
    if not os.path.exists(ENRICHED_PATH):
        print(f"No enriched file at {ENRICHED_PATH}", file=sys.stderr)
        sys.exit(1)

    with open(ENRICHED_PATH) as f:
        items = json.load(f)

    if not items:
        print("Empty enriched list — nothing to save.")
        return

    conn = get_db()
    saved = 0
    skipped = 0
    source_ids = set()

    for item in items:
        # Agent may mark item as skipped
        if item.get("skip"):
            # Insert as skipped so it's deduped on future runs
            skip_url = item.get("url")
            skip_source = item.get("source_id")
            skip_title = item.get("title", "skipped")
            if skip_url and skip_source:
                try:
                    with conn.cursor() as cur:
                        cur.execute("""
                            INSERT INTO news_items (source_id, title, url, status)
                            VALUES (%s, %s, %s, 'skipped')
                            ON CONFLICT (url) DO NOTHING
                        """, (skip_source, skip_title, skip_url))
                    conn.commit()
                except Exception:
                    conn.rollback()
            skipped += 1
            continue

        source_id = item.get("source_id")
        if not source_id:
            print(f"  [warn] no source_id on item: {item.get('title')}", file=sys.stderr)
            skipped += 1
            continue

        source_ids.add(source_id)

        tags = item.get("tags") or []
        if isinstance(tags, str):
            tags = [t.strip() for t in tags.split(",")]

        published_at = item.get("published_at")

        try:
            with conn.cursor() as cur:
                cur.execute("""
                    INSERT INTO news_items (
                        source_id, title, url, summary, image_url, video_url,
                        published_at, tags, status
                    ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
                    ON CONFLICT (url) DO UPDATE SET
                        summary = EXCLUDED.summary,
                        image_url = COALESCE(EXCLUDED.image_url, news_items.image_url),
                        tags = EXCLUDED.tags,
                        status = EXCLUDED.status
                    RETURNING id
                """, (
                    source_id,
                    item.get("title"),
                    item.get("url"),
                    item.get("summary"),
                    item.get("image_url"),
                    item.get("video_url"),
                    published_at,
                    tags,
                    item.get("status", "enriched"),
                ))
                row = cur.fetchone()
                if row:
                    saved += 1
                    print(f"  ✓ saved: {item.get('title')[:60]}", file=sys.stderr)
            conn.commit()
        except Exception as e:
            conn.rollback()
            print(f"  [error] failed to save '{item.get('title')}': {e}", file=sys.stderr)
            skipped += 1

    # Update last_fetched_at for all sources in this batch
    if source_ids:
        with conn.cursor() as cur:
            cur.execute(
                "UPDATE news_sources SET last_fetched_at = NOW() WHERE id = ANY(%s::uuid[])",
                (list(source_ids),)
            )
        conn.commit()

    conn.close()

    result = {"saved": saved, "skipped": skipped}
    print(json.dumps(result))


if __name__ == "__main__":
    main()
