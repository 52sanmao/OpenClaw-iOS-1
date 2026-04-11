# DB Schema — Skill Discovery

## skill_repos (new — grouping layer)

One row per GitHub repo containing skills.

| Column | Type | Notes |
|--------|------|-------|
| id | uuid | PK |
| name | text | Repo display name |
| slug | text UNIQUE | URL-safe |
| description | text | Repo-level description |
| github_url | text | Repo HTML URL |
| owner | text | GitHub owner/org |
| icon_url | text | Owner avatar fallback |
| banner_url | text | First image from repo README |
| github_stars | int | Repo star count |
| skill_count | int | Denormalised count of skills in this repo |
| keywords | text[] | Repo-level tags |
| source_url | text UNIQUE | Repo HTML URL — dedup key |
| status | app_status | `'approved'` for visible |
| created_at, updated_at, deleted_at | timestamptz | |

**Upsert by `source_url` (repo HTML URL).**

## agent_skills (existing + repo_id + status)

One row per SKILL.md file. Has FK to skill_repos.

| Column | Type | Notes |
|--------|------|-------|
| id | uuid | PK |
| repo_id | uuid FK | → skill_repos.id (nullable) |
| name | text | Skill identifier (from frontmatter) |
| slug | text UNIQUE | URL-safe, max 80 chars |
| display_name | text | Human-readable name |
| short_description | text | Max 160 chars, SEO-friendly |
| long_description | text | Markdown, 200-400 words |
| author | text | GitHub owner |
| author_url | text | Repo URL |
| github_url | text | Browse URL to SKILL.md file |
| source_path | text | Path within repo e.g. `skills/my-skill/SKILL.md` |
| skill_md_url | text | Raw GitHub URL to SKILL.md |
| source_url | text | Same as skill_md_url — dedup key |
| compatible_agents | text[] | Leave as `{}` — not used |
| triggers | text[] | Keywords that activate this skill |
| tags | text[] | Searchable tags |
| status | app_status | `'approved'` for visible |
| github_stars | int | Optional, inherited from repo |
| created_at, updated_at, published_at, deleted_at | timestamptz | |

**Upsert by `slug`. After upsert, update `skill_repos.skill_count`.**

## discovery_queue (shared, target_table='agent_skills')

`source_url` = raw SKILL.md URL (dedup per skill file, not per repo).

Metadata fields stored:
```json
{
  "mode": "skills",
  "skill_path": "skills/my-skill/SKILL.md",
  "skill_name": "my-skill",
  "skill_description": "...",
  "repo_stars": 42,
  "repo_description": "...",
  "repo_topics": [],
  "default_branch": "main",
  "pushed_at": "..."
}
```
