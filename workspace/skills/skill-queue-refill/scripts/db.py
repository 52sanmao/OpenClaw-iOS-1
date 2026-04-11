"""Database operations for discovery_queue."""

import json
import psycopg2


def connect(db_url: str):
    """Open a connection with autocommit."""
    conn = psycopg2.connect(db_url, sslmode="require")
    conn.autocommit = True
    return conn


def bulk_known_urls(cur, source_urls: list[str]) -> set[str]:
    """Batch-check which source_urls already exist in discovery_queue.
    Returns the set of URLs that are already known.
    """
    if not source_urls:
        return set()
    # Use ANY() for efficient batch lookup
    cur.execute(
        "SELECT source_url FROM discovery_queue WHERE source_url = ANY(%s)",
        (source_urls,),
    )
    return {row[0] for row in cur.fetchall()}


def repo_pending_count(cur, repo_full_name: str) -> int:
    """Count pending/processing skills from this repo."""
    cur.execute(
        """SELECT count(*) FROM discovery_queue
           WHERE repo_full_name=%s AND target_table='agent_skills'
           AND status IN ('pending','processing')""",
        (repo_full_name.lower(),),
    )
    return cur.fetchone()[0]


def insert_row(cur, source_url: str, repo_full_name: str, skill_path: str,
               repo_meta: dict | None, fm: dict,
               status: str, reason: str | None = None):
    """Insert a discovery_queue row. ON CONFLICT DO NOTHING for safety."""
    metadata = {
        "mode": "skills",
        "skill_path": skill_path,
        "skill_name": fm.get("name", ""),
        "skill_description": fm.get("description", ""),
        "repo_stars": repo_meta.get("stargazers_count", 0) if repo_meta else 0,
        "repo_description": repo_meta.get("description", "") if repo_meta else "",
        "repo_topics": repo_meta.get("topics", []) if repo_meta else [],
        "default_branch": repo_meta.get("default_branch", "main") if repo_meta else "main",
        "pushed_at": repo_meta.get("pushed_at", "") if repo_meta else "",
    }
    cur.execute(
        """
        INSERT INTO discovery_queue
            (source_url, repo_full_name, source_type, target_table, status, error, metadata)
        VALUES (%s, %s, 'github', 'agent_skills', %s, %s, %s)
        ON CONFLICT (source_url) DO NOTHING
        """,
        (source_url, repo_full_name.lower(), status, reason, json.dumps(metadata)),
    )
