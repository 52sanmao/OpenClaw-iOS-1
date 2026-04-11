#!/usr/bin/env python3
"""
save.py — Read /tmp/skill_audit_enriched.json, upsert to skill_audits,
          disable skill if flagged_malicious.

Usage: python3 save.py
Input: /tmp/skill_audit_enriched.json
"""

import json, os, sys
from pathlib import Path
import psycopg2

# Auto-load .env from skill root (parent of scripts/)
_env_file = Path(__file__).resolve().parent.parent / ".env"
if _env_file.exists():
    for line in _env_file.read_text().splitlines():
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            key, _, val = line.partition("=")
            os.environ.setdefault(key.strip(), val.strip())

DB_URL = os.environ.get("DATABASE_URL")

if not DB_URL:
    print("ERROR: DATABASE_URL not set", file=sys.stderr)
    sys.exit(1)

data = json.loads(Path("/tmp/skill_audit_enriched.json").read_text())

skill_id             = data["skill_id"]
security_score       = int(data["security_score"])
code_quality_score   = int(data["code_quality_score"])
architecture_score   = int(data["architecture_score"])
usefulness_score      = data.get("usefulness_score")
if usefulness_score is not None:
    usefulness_score = int(usefulness_score)
composite_score      = round(security_score * 0.5 + code_quality_score * 0.3 + architecture_score * 0.2)
run_tested           = bool(data.get("run_tested", False))
run_succeeded        = data.get("run_succeeded")
run_output           = data.get("run_output", "")[:2000] if data.get("run_output") else None
missing_deps         = data.get("missing_deps") or []
experience_summary   = data.get("experience_summary", "")
gotchas              = data.get("gotchas") or []
flagged_malicious    = bool(data.get("flagged_malicious", False))
audit_notes          = data.get("audit_notes", "")

conn = psycopg2.connect(DB_URL)
try:
    cur = conn.cursor()

    cur.execute("""
        INSERT INTO skill_audits (
            skill_id, security_score, code_quality_score, architecture_score,
            composite_score, usefulness_score,
            run_tested, run_succeeded, run_output,
            missing_deps, experience_summary, gotchas,
            flagged_malicious, audit_notes, audited_at
        ) VALUES (
            %s, %s, %s, %s,
            %s, %s,
            %s, %s, %s,
            %s, %s, %s,
            %s, %s, now()
        )
        ON CONFLICT (skill_id) DO UPDATE SET
            security_score       = EXCLUDED.security_score,
            code_quality_score   = EXCLUDED.code_quality_score,
            architecture_score   = EXCLUDED.architecture_score,
            composite_score      = EXCLUDED.composite_score,
            usefulness_score     = EXCLUDED.usefulness_score,
            run_tested           = EXCLUDED.run_tested,
            run_succeeded        = EXCLUDED.run_succeeded,
            run_output           = EXCLUDED.run_output,
            missing_deps         = EXCLUDED.missing_deps,
            experience_summary   = EXCLUDED.experience_summary,
            gotchas              = EXCLUDED.gotchas,
            flagged_malicious    = EXCLUDED.flagged_malicious,
            audit_notes          = EXCLUDED.audit_notes,
            audited_at           = now()
    """, (
        skill_id, security_score, code_quality_score, architecture_score,
        composite_score, usefulness_score,
        run_tested, run_succeeded, run_output,
        missing_deps, experience_summary, gotchas,
        flagged_malicious, audit_notes
    ))

    if flagged_malicious:
        cur.execute("""
            UPDATE agent_skills SET status = 'suspended', updated_at = now()
            WHERE id = %s
        """, (skill_id,))
        print(f"Skill {skill_id} DISABLED (flagged malicious)")

    conn.commit()
finally:
    conn.close()

slug = data.get("slug", skill_id)
print(f"Audit saved for: {slug}")
print(f"  security={security_score} quality={code_quality_score} arch={architecture_score} composite={composite_score} usefulness={usefulness_score}")
print(f"  run_tested={run_tested} run_succeeded={run_succeeded} flagged={flagged_malicious}")
