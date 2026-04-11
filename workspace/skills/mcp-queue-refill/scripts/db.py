"""Database operations for MCP discovery_queue."""

import json
import psycopg2


def connect(db_url: str):
    conn = psycopg2.connect(db_url, sslmode="require")
    conn.autocommit = True
    return conn


def get_cursor(cur, mode: str) -> str | None:
    """Get the latest discovery date for this mode."""
    cur.execute(
        """
        SELECT MAX(discovered_at) FROM discovery_queue
        WHERE target_table='apps' AND status NOT IN ('failed','skipped')
        AND (metadata->>'mode' = %s OR metadata->>'mode' IS NULL)
        """,
        (mode,),
    )
    row = cur.fetchone()
    return row[0].strftime("%Y-%m-%d") if row and row[0] else None


def bulk_known_repos(cur, repo_names: list[str]) -> set[str]:
    """Batch-check which repo_full_names already exist in discovery_queue."""
    if not repo_names:
        return set()
    normalised = [n.lower().strip("/").split("?")[0] for n in repo_names]
    cur.execute(
        "SELECT repo_full_name FROM discovery_queue WHERE repo_full_name = ANY(%s)",
        (normalised,),
    )
    return {row[0] for row in cur.fetchall()}


def insert_row(cur, repo: dict, status: str, mode: str, reason: str | None = None):
    full_name = repo["full_name"].lower().strip("/").split("?")[0]
    meta = {
        "stars":          repo.get("stargazers_count", 0),
        "description":    repo.get("description", ""),
        "topics":         repo.get("topics", []),
        "default_branch": repo.get("default_branch", "main"),
        "language":       repo.get("language", ""),
        "license":        repo.get("license", {}).get("spdx_id") if repo.get("license") else None,
        "pushed_at":      repo.get("pushed_at", ""),
        "mode":           mode,
    }
    cur.execute(
        """
        INSERT INTO discovery_queue
            (source_url, repo_full_name, source_type, target_table, status, error, metadata)
        VALUES (%s, %s, 'github', 'apps', %s, %s, %s)
        ON CONFLICT (source_url) DO NOTHING
        """,
        (repo["html_url"], full_name, status, reason, json.dumps(meta)),
    )
