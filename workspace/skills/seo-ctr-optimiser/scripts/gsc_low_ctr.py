#!/usr/bin/env python3
"""
Pull pages from GSC with >100 impressions and <3% CTR over last 28 days.
Outputs JSON: [{url, slug, impressions, ctr, position, top_queries}]
Sorted by impressions DESC (worst value pages first).

Usage:
  python3 gsc_low_ctr.py [--limit N]
"""

import json, os, sys, argparse
from datetime import date, timedelta
import requests
import skill_config

TOKEN_FILE = os.path.expanduser("~/.config/google-search-console/token.json")
CREDENTIALS_FILE = os.path.expanduser("~/.config/google-search-console/credentials.json")

_cfg = skill_config.load()
SITE = _cfg["gsc_site"]
SITE_URL = _cfg["site_url"]

def get_access_token():
    with open(TOKEN_FILE) as f:
        token_data = json.load(f)
    with open(CREDENTIALS_FILE) as f:
        creds = json.load(f)["installed"]
    resp = requests.post(creds["token_uri"], data={
        "client_id": creds["client_id"],
        "client_secret": creds["client_secret"],
        "refresh_token": token_data["refresh_token"],
        "grant_type": "refresh_token",
    })
    resp.raise_for_status()
    new_token = resp.json()
    token_data["access_token"] = new_token["access_token"]
    with open(TOKEN_FILE, "w") as f:
        json.dump(token_data, f, indent=2)
    return new_token["access_token"]

def gsc_query(access_token, body):
    url = f"https://www.googleapis.com/webmasters/v3/sites/{requests.utils.quote(SITE, safe='')}/searchAnalytics/query"
    resp = requests.post(url, headers={
        "Authorization": f"Bearer {access_token}",
        "Content-Type": "application/json"
    }, json=body)
    resp.raise_for_status()
    return resp.json()

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--limit", type=int, default=10, help="Max pages to return")
    parser.add_argument("--min-impressions", type=int, default=100)
    parser.add_argument("--max-ctr", type=float, default=0.03)
    args = parser.parse_args()

    end_date = date.today() - timedelta(days=3)  # GSC has ~3 day lag
    start_date = end_date - timedelta(days=28)

    access_token = get_access_token()

    # Get all pages
    pages_data = gsc_query(access_token, {
        "startDate": start_date.isoformat(),
        "endDate": end_date.isoformat(),
        "dimensions": ["page"],
        "rowLimit": 100,
        "orderBy": [{"fieldName": "impressions", "sortOrder": "DESCENDING"}]
    })

    candidates = []
    for row in pages_data.get("rows", []):
        url = row["keys"][0]
        impressions = row["impressions"]
        ctr = row["ctr"]
        position = row["position"]

        # Skip subdomains (ai.appwebdev.co.uk etc) — different codebase
        if not url.startswith(SITE_URL):
            continue
        # Skip low-value pages that never get clicks by intent
        path = url.replace(SITE_URL, "").rstrip("/") or "/"
        skip_patterns = ["/terms-conditions", "/privacy-policy", "/cookie-policy", "/#"]
        if any(path.startswith(p) for p in skip_patterns):
            continue
        if impressions < args.min_impressions:
            continue
        if ctr >= args.max_ctr:
            continue

        # Determine slug and page type
        if path == "/" or path == "":
            slug = "homepage"
        elif path.startswith("/blog/"):
            slug = path.replace("/blog/", "").rstrip("/")
        else:
            slug = path.lstrip("/").replace("/", "-")
        candidates.append({
            "url": url,
            "slug": slug,
            "page_type": "tsx" if slug in ("homepage", "openclaw", "blog") else "mdx",
            "impressions": int(impressions),
            "ctr": round(ctr, 4),
            "ctr_pct": round(ctr * 100, 2),
            "position": round(position, 1),
            "top_queries": []
        })

    # For each candidate, fetch top queries
    for page in candidates[:args.limit]:
        q_data = gsc_query(access_token, {
            "startDate": start_date.isoformat(),
            "endDate": end_date.isoformat(),
            "dimensions": ["query"],
            "dimensionFilterGroups": [{
                "filters": [{
                    "dimension": "page",
                    "operator": "equals",
                    "expression": page["url"]
                }]
            }],
            "rowLimit": 10,
            "orderBy": [{"fieldName": "impressions", "sortOrder": "DESCENDING"}]
        })
        page["top_queries"] = [
            {
                "query": r["keys"][0],
                "impressions": int(r["impressions"]),
                "clicks": int(r["clicks"]),
                "ctr_pct": round(r["ctr"] * 100, 2),
                "position": round(r["position"], 1)
            }
            for r in q_data.get("rows", [])
        ]

    print(json.dumps(candidates[:args.limit], indent=2))

if __name__ == "__main__":
    main()
