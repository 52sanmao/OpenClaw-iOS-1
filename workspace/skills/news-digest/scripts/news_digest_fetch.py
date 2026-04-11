#!/usr/bin/env python3
"""
news_digest_fetch.py — fetch items for a digest period.

Usage:
    python3 news_digest_fetch.py --mode day   [--date 2026-04-02]
    python3 news_digest_fetch.py --mode week  [--date 2026-04-02]   # week containing that date
    python3 news_digest_fetch.py --mode month [--date 2026-04-02]   # month containing that date
    python3 news_digest_fetch.py --mode quarter [--date 2026-04-02] # quarter containing that date

Defaults: --date = today (UTC)

Output (stdout): JSON object with:
  - mode, period_key, period_label, date_from, date_to
  - existing_digest: null | { id, title, summary_md, item_count, generated_at }
  - items: array of enriched news_items for the period
  - For week/month/quarter: also includes sub_digests (child digest summaries to build from)
"""

import argparse
import json
import os
import sys
from datetime import date, datetime, timedelta, timezone

import psycopg2

DATABASE_URL = os.environ.get("DATABASE_URL")


def get_db():
    return psycopg2.connect(DATABASE_URL)


def week_key(d: date) -> str:
    """ISO week key: 2026-W14"""
    return f"{d.isocalendar()[0]}-W{d.isocalendar()[1]:02d}"


def month_key(d: date) -> str:
    return d.strftime("%Y-%m")


def quarter_key(d: date) -> str:
    q = (d.month - 1) // 3 + 1
    return f"{d.year}-Q{q}"


def period_bounds(mode: str, d: date):
    """Return (date_from, date_to, period_key, period_label) for a given date and mode."""
    if mode == "day":
        return d, d, d.isoformat(), d.strftime("%B %-d, %Y")

    elif mode == "week":
        # ISO week: Monday to Sunday
        monday = d - timedelta(days=d.weekday())
        sunday = monday + timedelta(days=6)
        key = week_key(d)
        label = f"Week of {monday.strftime('%B %-d')}–{sunday.strftime('%-d, %Y')}"
        return monday, sunday, key, label

    elif mode == "month":
        first = d.replace(day=1)
        # Last day of month
        if d.month == 12:
            last = d.replace(day=31)
        else:
            last = d.replace(month=d.month + 1, day=1) - timedelta(days=1)
        key = month_key(d)
        label = d.strftime("%B %Y")
        return first, last, key, label

    elif mode == "quarter":
        q = (d.month - 1) // 3 + 1
        first_month = (q - 1) * 3 + 1
        first = d.replace(month=first_month, day=1)
        last_month = first_month + 2
        if last_month == 12:
            last = d.replace(month=12, day=31)
        else:
            last = d.replace(month=last_month + 1, day=1) - timedelta(days=1)
        key = quarter_key(d)
        label = f"Q{q} {d.year}"
        return first, last, key, label

    raise ValueError(f"Unknown mode: {mode}")


def get_existing_digest(conn, mode: str, period_key: str):
    with conn.cursor() as cur:
        cur.execute(
            """SELECT id, title, summary_md, item_count, generated_at
               FROM digests WHERE period_type = %s AND period_key = %s""",
            (mode, period_key)
        )
        row = cur.fetchone()
        if not row:
            return None
        return {
            "id": str(row[0]),
            "title": row[1],
            "summary_md": row[2],
            "item_count": row[3],
            "generated_at": row[4].isoformat() if row[4] else None,
        }


def get_items_for_period(conn, date_from: date, date_to: date):
    with conn.cursor() as cur:
        cur.execute(
            """SELECT n.id, n.title, n.url, n.summary, n.image_url, n.published_at, n.tags,
                      s.name as source_name, s.slug as source_slug
               FROM news_items n
               JOIN news_sources s ON s.id = n.source_id
               WHERE n.status = 'enriched'
               AND n.published_at::date BETWEEN %s AND %s
               ORDER BY n.published_at DESC""",
            (date_from, date_to)
        )
        cols = ["id", "title", "url", "summary", "image_url", "published_at", "tags",
                "source_name", "source_slug"]
        return [dict(zip(cols, row)) for row in cur.fetchall()]


def get_sub_digests(conn, sub_mode: str, date_from: date, date_to: date):
    """Get child digests for building higher-level summaries."""
    with conn.cursor() as cur:
        cur.execute(
            """SELECT id, period_key, title, summary_md, item_count, generated_at
               FROM digests
               WHERE period_type = %s
               AND generated_at IS NOT NULL
               ORDER BY period_key ASC""",
            (sub_mode,)
        )
        cols = ["id", "period_key", "title", "summary_md", "item_count", "generated_at"]
        all_subs = [dict(zip(cols, row)) for row in cur.fetchall()]

    # Filter to those within our date range by parsing the period_key
    result = []
    for s in all_subs:
        key = s["period_key"]
        try:
            if sub_mode == "day":
                d = date.fromisoformat(key)
            elif sub_mode == "week":
                year, week = key.split("-W")
                d = date.fromisocalendar(int(year), int(week), 1)
            elif sub_mode == "month":
                d = date.fromisoformat(key + "-01")
            else:
                continue
            if date_from <= d <= date_to:
                result.append(s)
        except Exception:
            pass
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=["day", "week", "month", "quarter"], required=True)
    parser.add_argument("--date", type=str, default=None,
                        help="Date within the period (ISO format, default: today UTC)")
    args = parser.parse_args()

    target_date = date.today() if not args.date else date.fromisoformat(args.date)
    date_from, date_to, period_key, period_label = period_bounds(args.mode, target_date)

    conn = get_db()

    existing = get_existing_digest(conn, args.mode, period_key)
    items = get_items_for_period(conn, date_from, date_to)

    # For week/month/quarter, also fetch sub-digests to write from
    sub_mode_map = {"week": "day", "month": "week", "quarter": "month"}
    sub_digests = []
    if args.mode in sub_mode_map:
        sub_digests = get_sub_digests(conn, sub_mode_map[args.mode], date_from, date_to)

    output = {
        "mode": args.mode,
        "period_key": period_key,
        "period_label": period_label,
        "date_from": date_from.isoformat(),
        "date_to": date_to.isoformat(),
        "today": date.today().isoformat(),
        "today_weekday": date.today().strftime("%A"),
        "existing_digest": existing,
        "item_count": len(items),
        "items": [
            {
                "id": str(i["id"]),
                "title": i["title"],
                "url": i["url"],
                "summary": i["summary"],
                "image_url": i["image_url"],
                "published_at": i["published_at"].isoformat() if i["published_at"] else None,
                "tags": i["tags"] or [],
                "source_name": i["source_name"],
                "source_slug": i["source_slug"],
            }
            for i in items
        ],
        "sub_digests": [
            {
                "id": str(s["id"]),
                "period_key": s["period_key"],
                "title": s["title"],
                "summary_md": s["summary_md"],
                "item_count": s["item_count"],
            }
            for s in sub_digests
        ],
    }

    conn.close()
    print(json.dumps(output, indent=2, default=str))


if __name__ == "__main__":
    main()
