---
name: skill-discovery
description: >-
  Discovers Agent Skills (SKILL.md files) on GitHub, enriches them with
  human-quality descriptions, and saves to the mcpapp-store.com database.
  Skills are grouped by repo (skill_repos table). The agent does the writing;
  scripts handle GitHub API and DB. Triggered by the skill discovery cron.
  See references/db-schema.md for schema.
metadata: {"openclaw":{"requires":{"bins":["python3"],"env":["DATABASE_URL","GITHUB_TOKEN"]},"emoji":"🔍"}}
---

# Skill Discovery — Enrichment

Discovers individual SKILL.md files on GitHub and creates two DB records per skill:
1. **`skill_repos`** — one per GitHub repo (the group/container)
2. **`agent_skills`** — one per SKILL.md file, linked to the repo

## Your workflow (3 steps)

### 1. Fetch raw data

```bash
python3 {baseDir}/scripts/fetch.py
```

The script auto-loads credentials from `{baseDir}/.env` — do NOT set env vars manually.

Outputs a JSON array. Each object contains:
- `queue_id`, `source_url` (raw SKILL.md URL), `repo_source_url`, `owner`, `repo_name`
- `skill_path`, `skill_md_url` (correct raw URL with right branch), `github_browse_url`
- `fm_name`, `fm_description` — raw frontmatter values
- `skill_md_body` — the skill instructions
- `repo_stars`, `repo_description`, `repo_banner_url`, `repo_icon_url`
- `has_scripts`, `has_references`, `sibling_files`

### 2. Write enriched content (you — no external API)

**PASSTHROUGH fields — copy exactly from fetch output, do NOT modify:**
```
queue_id, source_url, repo_source_url, owner, repo_name,
skill_path, skill_md_url, github_browse_url,
repo_stars, repo_description, repo_banner_url, repo_icon_url
```
These are required by save.py. If you drop any, the DB record will be broken.

**Fields you write:**
- `name` — the skill identifier slug from frontmatter (e.g. `commit-message`). Clean it: lowercase, hyphens only.
- `slug` — URL-safe unique slug. If multiple skills from same repo, prefix with repo name if needed to avoid conflicts: `repo-skill-name`.
- `display_name` — clean human-readable title (e.g. "Smart Commit Messages")
- `short_description` — max 160 chars. What does this skill help the agent do? Value-first, specific. Do NOT copy the frontmatter description verbatim — rewrite it to be clearer.
- `long_description` — markdown, 200-400 words:
  ```
  ## What it does
  What capability does this skill add to the agent? Concrete use case.

  ## When to use it
  Specific triggers/scenarios where this skill activates.

  ## What's included
  - Scripts: [list if has_scripts=true]
  - References: [list if has_references=true]
  - Instructions: brief summary of the procedural knowledge in the skill body

  ## Compatible agents
  Infer from skill description or repo README which agent tools support this
  (Claude Code, Cursor, Copilot, Codex, Gemini CLI, Goose, etc.)
  ```
- `tags` — 5-10 lowercase strings describing the skill's domain and use cases
- `triggers` — 3-8 keywords/phrases from the skill's description field that would trigger it

**Optional (override if needed):**
- `repo_display_name` — if the repo name is unclear, provide a better display name
- `repo_slug` — if the auto-generated slug would conflict

**Do NOT write:**
- `type`, `has_ui` — not applicable to skills
- `compatible_agents` — leave as `{}`, not used
- `install_command` — not applicable, github_url is sufficient

### 3. Save

Write enriched JSON array to `/tmp/skills_enriched.json`, then:

```bash
python3 {baseDir}/scripts/save.py --file /tmp/skills_enriched.json
```

save.py will:
- Upsert `skill_repos` by repo `source_url`
- Upsert `agent_skills` with `repo_id` FK
- Update `skill_repos.skill_count`
- Mark queue row `done`

## Quality signals to use

**Good skill (enrich it):**
- Clear, specific description — tells you exactly when to use it
- Non-trivial body — has real instructions, not just "Use this skill for X"
- Has `scripts/` or `references/` alongside SKILL.md — packed with real tools
- Stars on the repo suggest real users

**Marginal (still enrich but note it):**
- Very short body but specific description
- 0 stars but genuine content

**Skip (mark failed, don't save):**
- Clearly a demo/example/template that was never finished
- Description is obviously copy-paste boilerplate

## Reference

See `references/db-schema.md` for full field reference and SQL patterns.
