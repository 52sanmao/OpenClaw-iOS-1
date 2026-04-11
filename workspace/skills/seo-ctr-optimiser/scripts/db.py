#!/usr/bin/env python3
"""
db.py — Supabase backend for the CTR Optimiser skill.
PostgREST-backed DB for the CTR Optimiser. Works with any PostgREST instance (slim Postgres+PostgREST or full Supabase).

Usage:
    python3 db.py get <slug>
    python3 db.py upsert   (reads JSON from stdin)
    python3 db.py list
    python3 db.py setup     (creates table if not exists — idempotent)
"""

import sys
import json
import os
import urllib.request
import urllib.error
from datetime import date

# ── Config ────────────────────────────────────────────────────────────────────
CONFIG_PATH = os.path.expanduser("~/.config/supabase/config.json")

def load_config():
    with open(CONFIG_PATH) as f:
        return json.load(f)

def headers(config, role="service"):
    key = config.get("service_role_key") if role == "service" else config.get("anon_key")
    h = {"Content-Type": "application/json", "Prefer": "return=representation"}
    if key:  # skip auth entirely if no key set (internal-only slim stack)
        h["apikey"] = key
        h["Authorization"] = f"Bearer {key}"
    return h

def base_url(config):
    return config["url"].rstrip("/") + "/rest/v1"

def pg_url(config):
    return config["url"].rstrip("/") + "/pg"

# ── HTTP helpers ──────────────────────────────────────────────────────────────
def http(method, url, data=None, hdrs=None):
    body = json.dumps(data).encode() if data is not None else None
    req = urllib.request.Request(url, data=body, headers=hdrs or {}, method=method)
    try:
        with urllib.request.urlopen(req) as resp:
            raw = resp.read()
            return json.loads(raw) if raw else []
    except urllib.error.HTTPError as e:
        err = e.read().decode()
        print(f"HTTP {e.code} {method} {url}: {err}", file=sys.stderr)
        sys.exit(1)

# ── Operations ────────────────────────────────────────────────────────────────
def get_row(slug):
    """Get a single row by slug. Returns dict or None."""
    cfg = load_config()
    url = f"{base_url(cfg)}/ctr_pages?slug=eq.{slug}"
    hdrs = headers(cfg)
    hdrs["Prefer"] = ""
    result = http("GET", url, hdrs=hdrs)
    return result[0] if result else None

def upsert_row(data):
    """Upsert a row. Accepts dict with at minimum 'slug'."""
    cfg = load_config()
    url = f"{base_url(cfg)}/ctr_pages?on_conflict=slug"
    hdrs = headers(cfg)
    hdrs["Prefer"] = "return=representation,resolution=merge-duplicates"
    # Coerce types
    for numeric_field in ["impressions", "times_optimised"]:
        if numeric_field in data and data[numeric_field] is not None:
            data[numeric_field] = int(data[numeric_field])
    for float_field in ["ctr_pct", "avg_position"]:
        if float_field in data and data[float_field] is not None:
            data[float_field] = float(round(float(data[float_field]), 2))
    result = http("POST", url, data=[data], hdrs=hdrs)
    return result[0] if result else None

def list_rows(status=None):
    """List all rows, optionally filtered by status."""
    cfg = load_config()
    url = f"{base_url(cfg)}/ctr_pages?order=impressions.desc"
    if status:
        url += f"&status=eq.{status}"
    hdrs = headers(cfg)
    hdrs["Prefer"] = ""
    return http("GET", url, hdrs=hdrs)

def setup_table():
    """Create table + ENUM + trigger if not exists. Idempotent."""
    cfg = load_config()
    url = f"{pg_url(cfg)}/query"
    hdrs = headers(cfg)
    hdrs.pop("Prefer", None)

    statements = [
        "DO $$ BEGIN CREATE TYPE ctr_status AS ENUM ('Pending','Changed','Watching','Stable','GiveUp'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;",
        """
        CREATE TABLE IF NOT EXISTS ctr_pages (
            id               BIGSERIAL PRIMARY KEY,
            slug             TEXT NOT NULL UNIQUE,
            url              TEXT,
            current_title    TEXT,
            current_desc     TEXT,
            previous_title   TEXT,
            previous_desc    TEXT,
            impressions      INTEGER,
            ctr_pct          NUMERIC(5,2),
            avg_position     NUMERIC(6,2),
            top_queries      TEXT,
            status           ctr_status NOT NULL DEFAULT 'Pending',
            times_optimised  INTEGER NOT NULL DEFAULT 0,
            last_changed     DATE,
            grace_period_until DATE,
            notes            TEXT,
            created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
        );
        """,
        """
        CREATE OR REPLACE FUNCTION update_updated_at()
        RETURNS TRIGGER AS $$ BEGIN NEW.updated_at = NOW(); RETURN NEW; END; $$ LANGUAGE plpgsql;
        """,
        """
        DROP TRIGGER IF EXISTS ctr_pages_updated_at ON ctr_pages;
        CREATE TRIGGER ctr_pages_updated_at
            BEFORE UPDATE ON ctr_pages
            FOR EACH ROW EXECUTE FUNCTION update_updated_at();
        """,
    ]

    for sql in statements:
        http("POST", url, data={"query": sql.strip()}, hdrs=hdrs)

    print("✅ ctr_pages table ready")

# ── CLI ───────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    cmd = sys.argv[1]

    if cmd == "get":
        if len(sys.argv) < 3:
            print("Usage: db.py get <slug>", file=sys.stderr)
            sys.exit(1)
        row = get_row(sys.argv[2])
        print(json.dumps(row, indent=2, default=str))

    elif cmd == "upsert":
        data = json.load(sys.stdin)
        result = upsert_row(data)
        print(json.dumps(result, indent=2, default=str))

    elif cmd == "list":
        status_filter = sys.argv[2] if len(sys.argv) > 2 else None
        rows = list_rows(status_filter)
        print(json.dumps(rows, indent=2, default=str))

    elif cmd == "setup":
        setup_table()

    else:
        print(f"Unknown command: {cmd}", file=sys.stderr)
        sys.exit(1)
