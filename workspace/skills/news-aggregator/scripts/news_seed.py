#!/usr/bin/env python3
"""
news_seed.py — seed the news_sources table with initial sources.

Run once to populate. Re-running is safe (upserts by slug).

Usage:
    python3 news_seed.py
"""

import json
import os
import sys

import psycopg2

DATABASE_URL = os.environ.get("DATABASE_URL")

SOURCES = [
    {
        "slug": "claude-blog",
        "name": "Claude Blog",
        "url": "https://claude.com/blog",
        "rss_url": None,
        "scraper_key": "claude-blog",
        "category": "industry",
        "active": True,
    },
    # Add more sources here as we expand:
    # {
    #     "slug": "openai-news",
    #     "name": "OpenAI News",
    #     "url": "https://openai.com/news",
    #     "rss_url": "https://openai.com/news/rss.xml",
    #     "scraper_key": None,
    #     "category": "industry",
    #     "active": False,  # enable when ready
    # },
    # {
    #     "slug": "huggingface-blog",
    #     "name": "Hugging Face Blog",
    #     "url": "https://huggingface.co/blog",
    #     "rss_url": "https://huggingface.co/blog/feed.xml",
    #     "scraper_key": None,
    #     "category": "research",
    #     "active": False,
    # },
    # {
    #     "slug": "anthropic-research",
    #     "name": "Anthropic Research",
    #     "url": "https://www.anthropic.com/research",
    #     "rss_url": None,
    #     "scraper_key": "anthropic-research",
    #     "category": "research",
    #     "active": False,
    # },
]


def main():
    conn = psycopg2.connect(DATABASE_URL)

    for s in SOURCES:
        with conn.cursor() as cur:
            cur.execute("""
                INSERT INTO news_sources (slug, name, url, rss_url, scraper_key, category, active)
                VALUES (%s, %s, %s, %s, %s, %s, %s)
                ON CONFLICT (slug) DO UPDATE SET
                    name = EXCLUDED.name,
                    url = EXCLUDED.url,
                    rss_url = EXCLUDED.rss_url,
                    scraper_key = EXCLUDED.scraper_key,
                    category = EXCLUDED.category,
                    active = EXCLUDED.active
                RETURNING id, slug
            """, (s["slug"], s["name"], s["url"], s["rss_url"], s.get("scraper_key"), s["category"], s["active"]))
            row = cur.fetchone()
            print(f"  ✓ upserted: {row[1]} ({row[0]})")
        conn.commit()

    conn.close()
    print("Done.")


if __name__ == "__main__":
    main()
