#!/usr/bin/env python3
"""
fetch.py — Fetch raw data for the next pending repo(s) from discovery_queue.

Outputs structured JSON to stdout for the agent to enrich.
The agent reads this output, writes descriptions, then calls save.py.

Usage:
  python3 scripts/fetch.py                  # fetch 2 (1 starred + 1 fresh)
  python3 scripts/fetch.py --strategy starred
  python3 scripts/fetch.py --strategy fresh
  python3 scripts/fetch.py --limit 1
"""

import os
import re
import sys
import json
import time
import base64
import argparse
from pathlib import Path
import requests
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


def fetch_file(owner: str, repo: str, path: str, branch: str = "main") -> str | None:
    refs = list(dict.fromkeys([branch, "main", "master"]))
    for ref in refs:
        data = gh_get(
            f"https://api.github.com/repos/{owner}/{repo}/contents/{path}?ref={ref}"
        )
        if data and data.get("encoding") == "base64":
            try:
                return base64.b64decode(data["content"]).decode("utf-8", errors="replace")
            except Exception:
                return None
    return None


def fetch_file_tree(owner: str, repo: str, branch: str = "main") -> list[str]:
    data = gh_get(
        f"https://api.github.com/repos/{owner}/{repo}/git/trees/{branch}?recursive=0"
    )
    if not data:
        return []
    return [item["path"] for item in data.get("tree", [])]


def fetch_npm_stats(package_name: str) -> dict:
    try:
        resp = requests.get(f"https://registry.npmjs.org/{package_name}", timeout=10)
        if resp.status_code != 200:
            return {}
        data = resp.json()
        latest = data.get("dist-tags", {}).get("latest", "")
        return {
            "latest_version": latest,
            "description": data.get("description", ""),
            "keywords": data.get("keywords", []),
            "homepage": data.get("homepage", ""),
        }
    except Exception:
        return {}


def extract_images(readme: str) -> list[str]:
    urls = []
    for m in re.finditer(r'!\[.*?\]\((https?://[^\s)]+)\)', readme):
        urls.append(m.group(1))
    for m in re.finditer(r'<img[^>]+src=["\']([^"\']+)["\']', readme, re.IGNORECASE):
        urls.append(m.group(1))
    return [
        u for u in urls
        if not any(x in u for x in ["shields.io", "badge", "img.shields"])
    ][:6]


def find_icon(owner: str, repo_name: str, tree: list[str], pkg: dict) -> str:
    """
    Find the best icon URL, in priority order:
    1. manifest.json icon field (MCP Apps spec)
    2. icon.svg / icon.png / logo.svg / logo.png in repo root
    3. npm package icon from registry
    4. GitHub owner avatar as last resort
    """
    # 1. manifest.json
    if "manifest.json" in tree:
        manifest_text = fetch_file(owner, repo_name, "manifest.json")
        if manifest_text:
            try:
                manifest = json.loads(manifest_text)
                icon = manifest.get("icon") or manifest.get("iconUrl")
                if icon and icon.startswith("http"):
                    return icon
                if icon:
                    # relative path — build raw GitHub URL
                    return f"https://raw.githubusercontent.com/{owner}/{repo_name}/main/{icon.lstrip('/')}"
            except Exception:
                pass

    # 2. common icon file names in repo root
    icon_candidates = ["icon.svg", "icon.png", "logo.svg", "logo.png", "public/icon.png", "public/logo.png", "assets/icon.png"]
    for candidate in icon_candidates:
        if candidate in tree:
            return f"https://raw.githubusercontent.com/{owner}/{repo_name}/main/{candidate}"

    # 3. npm icon field
    npm_icon = pkg.get("icon") or ""
    if npm_icon and not npm_icon.startswith("."):
        return npm_icon

    # 4. fallback: GitHub owner avatar
    return f"https://github.com/{owner}.png?size=128"


def claim_pending(cur, strategy: str) -> dict | None:
    order = (
        "(metadata->>'stars')::int DESC NULLS LAST"
        if strategy == "starred"
        else "metadata->>'pushed_at' DESC NULLS LAST"
    )
    cur.execute(
        f"""
        UPDATE discovery_queue SET status = 'processing'
        WHERE id = (
            SELECT id FROM discovery_queue
            WHERE target_table = 'apps' AND status = 'pending'
            ORDER BY {order}
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


def fetch_repo_data(item: dict) -> dict:
    full_name = item["repo_full_name"]
    meta = item["metadata"]
    owner, repo_name = full_name.split("/", 1)
    branch = meta.get("default_branch", "main")

    pkg_text = fetch_file(owner, repo_name, "package.json", branch)
    time.sleep(0.4)
    readme = (
        fetch_file(owner, repo_name, "README.md", branch)
        or fetch_file(owner, repo_name, "readme.md", branch)
        or ""
    )
    time.sleep(0.4)
    tree = fetch_file_tree(owner, repo_name, branch)
    time.sleep(0.4)

    pkg = {}
    if pkg_text:
        try:
            pkg = json.loads(pkg_text)
        except json.JSONDecodeError:
            pass

    npm_package = pkg.get("name", "")
    npm_meta = {}
    if npm_package:
        npm_meta = fetch_npm_stats(npm_package)
        time.sleep(0.4)

    all_deps = {**pkg.get("dependencies", {}), **pkg.get("devDependencies", {})}
    app_type = "mcp-app" if "@modelcontextprotocol/ext-apps" in all_deps else "mcp-server"
    images = extract_images(readme)
    icon_url = find_icon(owner, repo_name, tree, pkg)
    time.sleep(0.2)

    # Separate banner (first non-logo image) from screenshots
    # Skip SVG logos and tiny badge-like images as banner
    banner_url = None
    screenshot_candidates = []
    for img in images:
        if any(x in img.lower() for x in [".svg", "logo", "badge", "icon"]):
            continue
        if banner_url is None:
            banner_url = img
        else:
            screenshot_candidates.append(img)

    # If no good banner found, use first image regardless
    if not banner_url and images:
        banner_url = images[0]
        screenshot_candidates = images[1:4]

    return {
        "queue_id": item["id"],
        "queue_mode": meta.get("mode", "apps"),  # 'apps' or 'servers' from search.py
        "source_url": item["source_url"],
        "repo_full_name": full_name,
        "owner": owner,
        "repo_name": repo_name,
        "app_type": app_type,
        "github_stars": meta.get("stars", 0),
        "github_description": meta.get("description", ""),
        "github_topics": meta.get("topics", []),
        "pushed_at": meta.get("pushed_at", ""),
        "default_branch": branch,
        "npm_package": npm_package,
        "npm_meta": npm_meta,
        "package_json": pkg,
        "readme": readme,
        "file_tree": tree[:40],
        "all_images": images,
        "banner_url": banner_url,
        "screenshot_urls": screenshot_candidates[:3],
        "icon_url": icon_url,
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--strategy", choices=["starred", "fresh", "both"], default="both")
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

    results = []

    try:
        # Auto-recover abandoned 'processing' rows (stuck > 30 min = prior run crashed)
        cur = conn.cursor()
        cur.execute(
            """
            UPDATE discovery_queue SET status = 'pending'
            WHERE status = 'processing'
              AND target_table = 'apps'
              AND processed_at IS NULL
              AND discovered_at < now() - interval '30 minutes'
            """
        )
        recovered = cur.rowcount
        conn.commit()
        if recovered:
            print(f"[recovery] Reset {recovered} abandoned processing rows to pending", flush=True)

        strategies = (
            ["starred", "fresh"] if args.strategy == "both"
            else [args.strategy] * args.limit
        )

        seen_ids = set()

        for strategy in strategies[:args.limit]:
            cur = conn.cursor()
            item = claim_pending(cur, strategy)
            conn.commit()

            if not item or item["id"] in seen_ids:
                continue
            seen_ids.add(item["id"])

            data = fetch_repo_data(item)
            data["_strategy"] = strategy
            results.append(data)
            time.sleep(1)
    finally:
        conn.close()

    print(json.dumps(results, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
