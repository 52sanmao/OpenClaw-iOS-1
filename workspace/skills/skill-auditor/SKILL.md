---
name: skill-auditor
description: >-
  Audits Agent Skills for security, code quality, architecture, and usefulness.
  Picks one unaudited skill from the DB, reads its SKILL.md and any bundled
  scripts, attempts to run scripts locally, scores them, and saves results to
  skill_audits. Disables skills that are flagged malicious. Use when running
  the skill audit cron, or when manually auditing a specific skill.
metadata: {"openclaw":{"requires":{"bins":["python3"],"env":["DATABASE_URL"]},"emoji":"🔎"}}
---

# Skill Auditor

Audits one unaudited skill per run: static analysis + optional script execution + structured scoring.

## Workflow (4 steps)

### 1. Fetch

```bash
python3 {baseDir}/scripts/fetch.py
```

The script auto-loads credentials from `{baseDir}/.env` — do NOT set env vars manually.

Outputs `/tmp/skill_audit_fetch.json` with:
- `skill_id`, `slug`, `skill_md_body` — the full SKILL.md content
- `scripts` — dict of `{filename: content}` for any bundled scripts (may be empty)
- `github_url`, `source_path` for reference

If output contains `{"nothing_to_audit": true}` — all skills are audited. Report that and stop.

### 2. Run scripts (if any)

If `scripts` is non-empty:

```bash
python3 {baseDir}/scripts/run_scripts.py
```

Outputs `/tmp/skill_audit_run.json` with per-script results (exit_code, stdout, stderr, succeeded).

Scripts run with `DRY_RUN=1` and `CI=1` env vars in a temp dir. They are cleaned up automatically.

### 3. Analyse and score (silently — do NOT write analysis to chat)

Read `skill_md_body`, `scripts`, and (if ran) `/tmp/skill_audit_run.json`. Score using the rubrics below. Do NOT output your reasoning — just write the scores directly into `/tmp/skill_audit_enriched.json` in Step 4.

#### Security score (0-100)
Start at 100. Deduct for each finding. Floor at 0.
- `curl | bash`, `wget | sh`, piping remote content to shell: -35
- Hardcoded credentials/tokens/API keys in scripts: -28
- `rm -rf /` or destructive commands without guards: -25
- Instructing agent to exfiltrate data or disable safety checks: -40 (likely malicious)
- Auto-update mechanism (git pull without confirmation): -18
- Telemetry/phone-home to external host: -15
- Network calls to unknown/suspicious hosts: -18
- Shell injection risk (unquoted vars, string interpolation in commands): -12
- Binary blob downloads without checksum verification: -10
- **`flagged_malicious = true`** if security_score < 40

Use the full range — a skill with one minor issue might score 87, not 80. Be precise.

#### Code quality score (0-100)
Scoring anchors:
- **15-30**: No real instructions, boilerplate/empty, scripts that all crash on import
- **31-45**: Minimal instructions, poor error handling, vague steps, missing context
- **46-60**: Functional but rough — some error handling, steps present but incomplete
- **61-74**: Good structure, error handling present, clear steps, minor gaps
- **75-86**: Well-written, idempotent scripts, clear variable names, good comments
- **87-100**: Exceptional — production-quality code, full error handling, great docs

Consider: scripts run correctly, SKILL.md triggers are specific, instructions are unambiguous.

#### Architecture score (0-100)
Scoring anchors:
- **10-25**: Monolithic dump, no frontmatter, no separation of concerns
- **26-42**: Basic structure present but scripts/references mixed or missing
- **43-58**: Frontmatter complete, some separation, output contracts vague
- **59-72**: Good structure, scripts/ or references/ used, clear output contracts
- **73-85**: Follows skill spec well, lean SKILL.md, good progressive disclosure
- **86-100**: Exemplary — perfect separation, clear contracts, references/ well-organised

#### Usefulness score (0-100, or null)
Agent judgment — how many real users would benefit and could use it today:
- **Demand**: Solves a real, common problem vs niche edge case
- **Breadth**: Niche audience (15-35) -> specific audience (36-58) -> broad (59-78) -> universal (79-100)
- **Practicality**: Works out of the box vs needs heavy setup/missing deps
- **Uniqueness**: Only skill doing this vs one of many duplicates

Set to `null` only if skill body is empty/garbage. Always use your best judgment.

#### Composite score
`round(security * 0.5 + quality * 0.3 + arch * 0.2)` — computed by save.py automatically (range 0-100).

### 4. Save

Write `/tmp/skill_audit_enriched.json` with your analysis, then:

```bash
python3 {baseDir}/scripts/save.py
```

#### Output schema

```json
{
  "skill_id": "<uuid from fetch>",
  "slug": "<slug from fetch>",
  "security_score": 80,
  "code_quality_score": 70,
  "architecture_score": 60,
  "usefulness_score": 60,
  "run_tested": true,
  "run_succeeded": true,
  "run_output": "first 500 chars of combined stdout/stderr from all scripts",
  "missing_deps": ["some-package"],
  "experience_summary": "2-4 sentence narrative: what the skill does, how the scripts behaved, notable findings",
  "gotchas": ["Watch out for X", "Requires Y env var to be set"],
  "flagged_malicious": false,
  "audit_notes": "freeform: anything else worth noting"
}
```

**Rules:**
- `run_tested` = true only if run_scripts.py actually executed (scripts were present)
- `run_succeeded` = true if any script exited 0; null if not run
- `run_output` = concatenate stdout/stderr snippets across all scripts, trim to ~500 chars
- `missing_deps` = list packages/tools that caused ImportError/command-not-found — install them with pip if simple, note if too complex
- `flagged_malicious` = true if security_score < 40
- `experience_summary` — write this even if scripts weren't run (static analysis still has value)

## Report

Your ENTIRE response must be exactly one line (this is sent directly to Telegram):
Audited: <slug> | sec=X qual=X arch=X comp=X use=X | flagged=yes/no

Do NOT add any other text, preamble, analysis, or confirmation. Just the one line.

## See also

- `references/db-schema.md` — full SQL schema and query patterns
