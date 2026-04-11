#!/usr/bin/env python3
"""
news_fetch.py — fetch new items from a single news source.

Usage:
    python3 news_fetch.py --source <source_id_or_slug>
    python3 news_fetch.py --list-sources

Outputs JSON array of new (unseen) raw items to stdout.
Each item includes: source_id, title, url, raw_description, published_at, category, og_image (if fetched)

Strategy per source:
  - rss_url set → parse RSS/Atom feed
  - rss_url null → scrape listing page (source-specific scraper)
"""

import argparse
import json
import os
import re
import sys
import time
from datetime import datetime, timezone
from urllib.parse import urljoin
from pathlib import Path

import psycopg2
import requests
from bs4 import BeautifulSoup

# Auto-load .env from skill root (parent of scripts/)
_env_file = Path(__file__).resolve().parent.parent / ".env"
if _env_file.exists():
    for line in _env_file.read_text().splitlines():
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            key, _, val = line.partition("=")
            os.environ.setdefault(key.strip(), val.strip())

DATABASE_URL = os.environ.get("DATABASE_URL")
HEADERS = {
    "User-Agent": "Mozilla/5.0 (compatible; MCPAppStore-NewsBot/1.0; +https://mcpapp-store.com)"
}


def get_db():
    return psycopg2.connect(DATABASE_URL)


def fetch_og_meta(url: str) -> dict:
    """Fetch og:image and og:description from an article URL."""
    try:
        r = requests.get(url, headers=HEADERS, timeout=10)
        if r.status_code != 200:
            return {}
        soup = BeautifulSoup(r.text, "html.parser")
        og = {}
        tag = soup.find("meta", property="og:image")
        if tag and tag.get("content"):
            og["og_image"] = tag["content"]
        tag = soup.find("meta", property="og:description")
        if tag and tag.get("content"):
            og["og_description"] = tag["content"]
        tag = soup.find("meta", property="article:published_time")
        if tag and tag.get("content"):
            og["og_published_at"] = tag["content"]
        return og
    except Exception as e:
        print(f"  [warn] og fetch failed for {url}: {e}", file=sys.stderr)
        return {}


def parse_rss(rss_url: str) -> list:
    """Parse an RSS/Atom feed, return list of raw items."""
    import xml.etree.ElementTree as ET

    r = requests.get(rss_url, headers=HEADERS, timeout=15)
    r.raise_for_status()
    root = ET.fromstring(r.text)

    ns = {
        "atom": "http://www.w3.org/2005/Atom",
        "content": "http://purl.org/rss/1.0/modules/content/",
        "dc": "http://purl.org/dc/elements/1.1/",
        "media": "http://search.yahoo.com/mrss/",
    }

    items = []

    # RSS 2.0
    for item in root.findall(".//item"):
        def t(tag):
            el = item.find(tag)
            return el.text.strip() if el is not None and el.text else None

        title = t("title")
        url = t("link") or t("guid")
        description = t("description")
        pub_date = t("pubDate")
        category = t("category")

        # media:content image (used by Google blog and others)
        media_img = None
        media_el = item.find("media:content", ns)
        if media_el is not None:
            media_img = media_el.get("url")

        if not title or not url:
            continue

        # Parse pubDate
        published_at = None
        if pub_date:
            try:
                from email.utils import parsedate_to_datetime
                published_at = parsedate_to_datetime(pub_date).isoformat()
            except Exception:
                pass

        item_data = {
            "title": title,
            "url": url.strip(),
            "raw_description": description,
            "published_at": published_at,
            "category": category,
        }
        if media_img:
            item_data["og_image"] = media_img  # pre-populate image from RSS

        items.append(item_data)

    # Atom fallback
    if not items:
        for entry in root.findall("atom:entry", ns):
            def ta(tag):
                el = entry.find(tag, ns)
                return el.text.strip() if el is not None and el.text else None

            title = ta("atom:title")
            link_el = entry.find("atom:link", ns)
            url = link_el.get("href") if link_el is not None else None
            summary = ta("atom:summary")
            published = ta("atom:published") or ta("atom:updated")

            if not title or not url:
                continue

            items.append({
                "title": title,
                "url": url.strip(),
                "raw_description": summary,
                "published_at": published,
                "category": None,
            })

    return items


def scrape_claude_blog() -> list:
    """
    Scrape claude.com/blog listing page.
    Reads actual <a href> slugs from the page — never constructs slugs from titles.
    Returns list of raw items with title, url, published_at.
    """
    r = requests.get("https://claude.com/blog", headers=HEADERS, timeout=15)
    r.raise_for_status()
    soup = BeautifulSoup(r.text, "html.parser")

    items = []
    seen_hrefs = set()

    # Collect all valid blog post hrefs from the page
    for a in soup.find_all("a", href=True):
        href = a["href"]
        # Must be a blog post path, not a category/filter
        if not href.startswith("/blog/") and not href.startswith("https://claude.com/blog/"):
            continue
        # Normalise to relative
        if href.startswith("https://claude.com"):
            href = href[len("https://claude.com"):]
        # Skip category pages
        if "/blog/category/" in href or href in ("/blog", "/blog/"):
            continue

        if href in seen_hrefs:
            continue
        seen_hrefs.add(href)

        url = "https://claude.com" + href
        text = a.get_text(separator=" ", strip=True)

        # Skip nav/filter links with no real title
        if not text or text.lower() in ("read more", "blog", "back", "next", "prev"):
            # Still add URL with no title — OG fetch will get the title
            items.append({
                "title": None,
                "url": url,
                "raw_description": None,
                "published_at": None,
                "category": None,
                "_needs_og": True,
            })
            continue

        items.append({
            "title": text,
            "url": url,
            "raw_description": None,
            "published_at": None,
            "category": None,
            "_needs_og": True,
        })

    return items


def scrape_anthropic_engineering() -> list:
    """
    Scrape anthropic.com/engineering listing page.
    Returns list of raw items with title, url, published_at.
    Slugs are exact from the page — no guessing needed.
    """
    r = requests.get("https://www.anthropic.com/engineering", headers=HEADERS, timeout=15)
    r.raise_for_status()
    soup = BeautifulSoup(r.text, "html.parser")

    items = []
    seen_urls = set()

    # Each article is an <a> tag with href like /engineering/slug and a date span
    for a in soup.find_all("a", href=True):
        href = a["href"]
        if not href.startswith("/engineering/"):
            continue
        url = "https://www.anthropic.com" + href
        if url in seen_urls:
            continue
        seen_urls.add(url)

        # Extract title — full text of the link, strip date suffixes
        full_text = a.get_text(separator=" ", strip=True)

        # Strip "Featured" prefix (used on pinned articles)
        full_text = re.sub(r'^Featured\s+', '', full_text).strip()

        # Date pattern at end: "Mar 25, 2026" or "Jan 09, 2026" etc.
        date_match = re.search(
            r"(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+\d{1,2},\s+\d{4}$",
            full_text
        )
        published_at = None
        if date_match:
            date_str = date_match.group(0)
            title = full_text[:date_match.start()].strip()
            try:
                published_at = datetime.strptime(date_str, "%b %d, %Y").replace(tzinfo=timezone.utc).isoformat()
            except Exception:
                pass
        else:
            # No date in listing (e.g. featured article) — title is everything
            # but strip any appended description text after a long title
            # Heuristic: if text is very long, truncate at first sentence boundary
            title = full_text
            if len(title) > 120:
                # Take only up to first period or em-dash that isn't part of a word
                short = re.split(r'(?<=\w)[—–]|(?<=[.!?])\s', title)
                title = short[0].strip() if short else title[:120]

        if not title or len(title) < 5:
            continue

        items.append({
            "title": title,
            "url": url,
            "raw_description": None,
            "published_at": published_at,
            "category": "engineering",
            "_needs_og": True,
        })

    return items


def scrape_openai_dev_blog() -> list:
    """
    Scrape developers.openai.com/blog listing page.
    Format: each article is an <a href="/blog/slug"> with text like:
    "Mar 25How Perplexity Brought Voice Search...description...Category"
    Exact slugs available directly from href. Dates in 'Mon DD' format (year inferred).
    """
    r = requests.get("https://developers.openai.com/blog", headers=HEADERS, timeout=15)
    r.raise_for_status()
    soup = BeautifulSoup(r.text, "html.parser")

    items = []
    seen_urls = set()
    current_year = datetime.now(timezone.utc).year

    for a in soup.find_all("a", href=True):
        href = a["href"]
        if not href.startswith("/blog/") or href == "/blog" or href.startswith("/blog/topic/"):
            continue

        full_text = a.get_text(separator="", strip=True)

        # Only process links that START with a date (Mon DD format)
        # This filters out the featured/hero duplicates that have no date prefix
        date_match = re.match(
            r'^(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s*(\d{1,2})(.+)',
            full_text
        )
        if not date_match:
            continue

        url = "https://developers.openai.com" + href
        if url in seen_urls:
            continue
        seen_urls.add(url)

        month_str = date_match.group(1)
        day_str = date_match.group(2)
        remainder = date_match.group(3).strip()

        # Infer year: if month is in the future vs today, it's last year
        try:
            dt = datetime.strptime(f"{month_str} {day_str} {current_year}", "%b %d %Y")
            if dt > datetime.now(timezone.utc).replace(tzinfo=None):
                dt = dt.replace(year=current_year - 1)
            published_at = dt.replace(tzinfo=timezone.utc).isoformat()
        except Exception:
            published_at = None

        # Title is the remainder — it blends into description, take up to ~120 chars
        # Split on known category keywords at end
        categories = ["Audio", "General", "API", "Codex", "Apps SDK", "Commerce"]
        title = remainder
        category = None
        for cat in categories:
            if remainder.endswith(cat):
                title = remainder[:-len(cat)].strip()
                category = cat
                break

        # Title bleeds into description — heuristic cut at ~100 chars or sentence boundary
        if len(title) > 120:
            cut = re.search(r'(?<=[a-z\.\!\?])\s+[A-Z]', title[40:])
            if cut:
                title = title[:40 + cut.start() + 1].strip()
            else:
                title = title[:100].strip()

        if not title or len(title) < 5:
            continue

        items.append({
            "title": title,
            "url": url,
            "raw_description": None,
            "published_at": published_at,
            "category": category,
            "_needs_og": True,
        })

    return items


def scrape_cursor_blog() -> list:
    """
    Scrape cursor.com/blog listing page.
    Format: each article <a href="/blog/slug"> text like:
    "Apr 2, 2026 · Product Title text Description Author Xm"
    Exact slugs from href. Dates in 'Mon D, YYYY' format.
    Skip customer story posts (no date prefix) and 'Read more' links.
    """
    r = requests.get("https://cursor.com/blog", headers=HEADERS, timeout=15)
    r.raise_for_status()
    soup = BeautifulSoup(r.text, "html.parser")

    items = []
    seen_urls = set()

    for a in soup.find_all("a", href=True):
        href = a["href"]
        if not href.startswith("/blog/") or href in ("/blog/", "/blog"):
            continue
        if any(x in href for x in ["/topic/", "/changelog"]):
            continue

        url = "https://cursor.com" + href
        if url in seen_urls:
            continue

        full_text = a.get_text(separator=" ", strip=True)

        # Must start with a date: "Apr 2, 2026 ·" or "Feb 26, 2026 ·"
        date_match = re.match(
            r'^(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+(\d{1,2}),\s+(\d{4})\s*[·\-]\s*(.+)',
            full_text
        )
        if not date_match:
            continue  # customer stories, press, 'Read more' links — skip

        seen_urls.add(url)

        month_str = date_match.group(1)
        day_str = date_match.group(2)
        year_str = date_match.group(3)
        remainder = date_match.group(4).strip()

        published_at = None
        try:
            published_at = datetime.strptime(
                f"{month_str} {day_str} {year_str}", "%b %d %Y"
            ).replace(tzinfo=timezone.utc).isoformat()
        except Exception:
            pass

        # remainder: "Product Title text Description Author Xm"
        # Strip category (first word if title-cased and short)
        categories = ["Product", "Research", "Ideas", "product", "research", "ideas", "Changelog"]
        category = None
        for cat in categories:
            if remainder.startswith(cat + " "):
                category = cat.lower()
                remainder = remainder[len(cat):].strip()
                break

        # Title ends where description-like text begins or at author name
        # Heuristic: title is first sentence / up to ~80 chars before lowercase continuation
        title = remainder
        if len(title) > 100:
            # Cut at first sentence-like break after a capital-starting phrase
            cut = re.search(r'(?<=[a-z\.\!\?])\s+[A-Z]', title[20:])
            if cut:
                title = title[:20 + cut.start() + 1].strip()
            else:
                title = title[:90].strip()

        # Strip trailing author/time: patterns like "Author 3m", "Author · 3m", "A & B 7m A & B · 7m"
        title = re.sub(r'\s+[\w,&\s]+\s+·\s+\d+m$', '', title).strip()
        title = re.sub(r'\s+[\w,&\s]+\s+\d+m\s+[\w,&\s]+\s+·\s+\d+m$', '', title).strip()
        title = re.sub(r'\s+\d+m$', '', title).strip()

        if not title or len(title) < 5:
            continue

        items.append({
            "title": title,
            "url": url,
            "raw_description": None,
            "published_at": published_at,
            "category": category,
            "_needs_og": True,
        })

    return items


SCRAPERS = {
    "claude-blog": scrape_claude_blog,
    "anthropic-engineering": scrape_anthropic_engineering,
    "openai-dev-blog": scrape_openai_dev_blog,
    "cursor-blog": scrape_cursor_blog,
}


def get_existing_urls(conn, source_id: str) -> set:
    with conn.cursor() as cur:
        cur.execute("SELECT url FROM news_items WHERE source_id = %s", (source_id,))
        return {row[0] for row in cur.fetchall()}


def get_source(conn, source_id_or_slug: str) -> dict | None:
    with conn.cursor() as cur:
        cur.execute(
            "SELECT id, name, url, rss_url, category, active, scraper_key FROM news_sources WHERE id::text = %s OR slug = %s",
            (source_id_or_slug, source_id_or_slug)
        )
        row = cur.fetchone()
        if not row:
            return None
        cols = ["id", "name", "url", "rss_url", "category", "active", "scraper_key"]
        return dict(zip(cols, row))


def list_sources(conn) -> list:
    with conn.cursor() as cur:
        cur.execute("SELECT id, name, slug, url, rss_url, active, last_fetched_at FROM news_sources ORDER BY last_fetched_at ASC NULLS FIRST")
        cols = ["id", "name", "slug", "url", "rss_url", "active", "last_fetched_at"]
        return [dict(zip(cols, row)) for row in cur.fetchall()]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", help="Source id or slug to fetch (default: all active sources)")
    parser.add_argument("--all-sources", action="store_true", help="Fetch from all active sources (default behaviour when --source not given)")
    parser.add_argument("--list-sources", action="store_true", help="List all sources")
    parser.add_argument("--with-og", action="store_true", default=True, help="Fetch OG meta for each item (default: True)")
    parser.add_argument("--no-og", action="store_true", help="Skip OG meta fetching")
    parser.add_argument("--limit", type=int, default=8, help="Max new items to return per run (default: 8)")
    parser.add_argument("--since", type=str, default=None, help="Only return items published after this date (ISO format, e.g. 2026-01-01)")
    args = parser.parse_args()

    fetch_og = args.with_og and not args.no_og

    conn = get_db()

    if args.list_sources:
        sources = list_sources(conn)
        print(json.dumps(sources, indent=2, default=str))
        return

    # Determine which sources to fetch
    if args.source:
        source = get_source(conn, args.source)
        if not source:
            print(f"Source not found: {args.source}", file=sys.stderr)
            sys.exit(1)
        sources_to_fetch = [source]
    else:
        # Default: all active sources
        all_sources = list_sources(conn)
        sources_to_fetch = [s for s in all_sources if s["active"]]

    all_new_items = []

    for source in sources_to_fetch:
        print(f"Fetching source: {source['name']} ({source['id']})", file=sys.stderr)

        # Get raw items
        raw_items = []
        try:
            if source.get("rss_url"):
                print(f"  Strategy: RSS → {source['rss_url']}", file=sys.stderr)
                raw_items = parse_rss(source["rss_url"])
            else:
                scraper_key = source.get("scraper_key") or source.get("slug")
                scraper = SCRAPERS.get(scraper_key)
                if not scraper:
                    print(f"  No scraper for key: {scraper_key}", file=sys.stderr)
                    continue
                print(f"  Strategy: scraper → {scraper_key}", file=sys.stderr)
                raw_items = scraper()
        except Exception as e:
            print(f"  [error] fetch failed for {source['name']}: {e}", file=sys.stderr)
            continue

        print(f"  Raw items: {len(raw_items)}", file=sys.stderr)

        # Deduplicate against DB
        existing_urls = get_existing_urls(conn, str(source["id"]))
        new_items = [item for item in raw_items if item["url"] not in existing_urls]

        # Apply --since filter
        if args.since:
            try:
                since_dt = datetime.fromisoformat(args.since).replace(tzinfo=timezone.utc)
                before = len(new_items)
                new_items = [i for i in new_items if i.get('published_at') and datetime.fromisoformat(i['published_at'].replace('Z','+00:00')) >= since_dt]
                print(f"  After --since {args.since}: {len(new_items)} (filtered {before - len(new_items)})", file=sys.stderr)
            except Exception as e:
                print(f"  [warn] --since parse error: {e}", file=sys.stderr)

        print(f"  New items: {len(new_items)}", file=sys.stderr)

        if not new_items:
            continue

        # Fetch OG for new items (unless --no-og)
        fetch_og = not args.no_og
        if fetch_og:
            for item in new_items:
                needs_og = item.pop("_needs_og", False) or not item.get("raw_description")
                if needs_og and not item.get("og_image"):
                    print(f"  Fetching OG: {item['url']}", file=sys.stderr)
                    og = fetch_og_meta(item["url"])
                    item.update(og)
                    time.sleep(0.5)

        # Attach source_id
        for item in new_items:
            item["source_id"] = str(source["id"])
            item["source_name"] = source["name"]

        all_new_items.extend(new_items)

    # Apply global limit across all sources
    all_new_items = all_new_items[:args.limit]
    print(f"Total new items (capped at {args.limit}): {len(all_new_items)}", file=sys.stderr)

    print(json.dumps(all_new_items, indent=2, default=str))


if __name__ == "__main__":
    main()
