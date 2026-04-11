# DB Schema — Skill Auditor

## skill_audits (new table — create before first run)

One row per audit run per skill. Re-running replaces the previous row (upsert by skill_id).

```sql
CREATE TABLE IF NOT EXISTS skill_audits (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  skill_id             uuid NOT NULL REFERENCES agent_skills(id) ON DELETE CASCADE,

  -- Scores (0–100, higher = better)
  security_score       int NOT NULL,          -- 0-100
  code_quality_score   int NOT NULL,          -- 0-100
  architecture_score   int NOT NULL,          -- 0-100
  composite_score      int NOT NULL,          -- weighted: security*0.5 + quality*0.3 + arch*0.2 (0-100)

  -- Usefulness (agent judgment, nullable)
  usefulness_score     int,            -- 0-100: how genuinely useful? null = not assessed

  -- Execution
  run_tested           boolean NOT NULL DEFAULT false,
  run_succeeded        boolean,
  run_output           text,          -- first 2000 chars of stdout/stderr
  missing_deps         text[],        -- deps that blocked execution

  -- Agent narrative
  experience_summary   text,          -- what the agent observed running/reading it
  gotchas              text[],        -- watch-out notes
  flagged_malicious    boolean NOT NULL DEFAULT false,

  -- Misc
  audit_notes          text,
  audited_at           timestamptz NOT NULL DEFAULT now(),

  UNIQUE (skill_id)
);
```

## agent_skills — flag on malicious

When `flagged_malicious = true`, set:
```sql
UPDATE agent_skills SET status = 'disabled', updated_at = now() WHERE id = :skill_id;
```

## Querying unaudited skills

```sql
SELECT s.id, s.slug, s.source_url, s.skill_md_url, s.github_url, s.source_path
FROM agent_skills s
LEFT JOIN skill_audits a ON a.skill_id = s.id
WHERE s.deleted_at IS NULL
  AND s.status != 'disabled'
  AND a.id IS NULL
ORDER BY s.created_at ASC
LIMIT 1;

-- NOTE: Use source_url (raw.githubusercontent.com) for fetching content.
-- skill_md_url is the GitHub HTML page URL (not fetchable as raw text).
```
