#!/usr/bin/env python3
"""
news_digest_save.py — save a digest to the DB.

Reads from /tmp/digest_enriched.json, upserts to digests table.

Input JSON fields:
  mode, period_key, title, summary_md, item_ids (list of UUIDs)
"""

import json
import os
import sys
from datetime import datetime, timezone

import psycopg2

DATABASE_URL = os.environ.get("DATABASE_URL")
ENRICHED_PATH = "/tmp/digest_enriched.json"


def main():
    if not os.path.exists(ENRICHED_PATH):
        print(f"No file at {ENRICHED_PATH}", file=sys.stderr)
        sys.exit(1)

    with open(ENRICHED_PATH) as f:
        d = json.load(f)

    conn = psycopg2.connect(DATABASE_URL)
    now = datetime.now(timezone.utc)

    item_ids = d.get("item_ids", [])

    # Derive source_ids from item_ids if not provided
    source_ids = d.get("source_ids", [])
    if not source_ids and item_ids:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT DISTINCT source_id::text FROM news_items WHERE id = ANY(%s::uuid[])",
                (item_ids,)
            )
            source_ids = [r[0] for r in cur.fetchall()]

    with conn.cursor() as cur:
        cur.execute("""
            INSERT INTO digests (period_type, period_key, title, summary_md, item_ids, source_ids, item_count, generated_at, updated_at)
            VALUES (%s, %s, %s, %s, %s::uuid[], %s::uuid[], %s, %s, %s)
            ON CONFLICT (period_type, period_key) DO UPDATE SET
                title = EXCLUDED.title,
                summary_md = EXCLUDED.summary_md,
                item_ids = EXCLUDED.item_ids,
                source_ids = EXCLUDED.source_ids,
                item_count = EXCLUDED.item_count,
                updated_at = EXCLUDED.updated_at
            RETURNING id, period_type, period_key
        """, (
            d["mode"],
            d["period_key"],
            d["title"],
            d["summary_md"],
            item_ids,
            source_ids,
            d.get("item_count", len(item_ids)),
            now,
            now,
        ))
        row = cur.fetchone()
        conn.commit()
        result = {"id": str(row[0]), "period_type": row[1], "period_key": row[2]}

    conn.close()
    print(json.dumps(result))


if __name__ == "__main__":
    main()
