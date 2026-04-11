# DB Schema Reference — MCP App Discovery

## Connection

```
DATABASE_URL=postgresql://postgres:PASSWORD@db.PROJECT.supabase.co:5432/postgres
```

Use `ssl='require'` with the `postgres` Python library.

---

## discovery_queue

Shared state across all scraper agents. One row per source URL ever seen.

| Column | Type | Notes |
|--------|------|-------|
| id | uuid | PK, auto |
| source_url | text UNIQUE | dedup key — `ON CONFLICT DO NOTHING` |
| repo_full_name | text | `owner/repo` |
| source_type | text | `'github'` |
| target_table | text | `'apps'` / `'agent_skills'` / `'ai_models'` |
| status | text | `'pending'` → `'processing'` → `'done'` / `'failed'` |
| discovered_at | timestamptz | auto, use `MAX()` as cursor |
| processed_at | timestamptz | set when done |
| error | text | error message if failed |
| metadata | jsonb | raw GitHub API response fields |

**Cursor query:**
```sql
SELECT MAX(discovered_at) FROM discovery_queue
WHERE target_table = 'apps' AND status != 'failed'
```

**Claim a row atomically:**
```sql
UPDATE discovery_queue
SET status = 'processing'
WHERE id = (
  SELECT id FROM discovery_queue
  WHERE target_table = 'apps' AND status = 'pending'
  ORDER BY discovered_at ASC
  LIMIT 1
  FOR UPDATE SKIP LOCKED
)
RETURNING *
```

---

## apps

Main listing table for both MCP Apps and MCP Servers.

| Column | Type | Notes |
|--------|------|-------|
| id | uuid | PK, auto |
| type | enum | `'mcp-app'` or `'mcp-server'` — REQUIRED |
| publisher_id | uuid FK | → organizations.id — REQUIRED |
| name | text | Display name |
| slug | text UNIQUE | URL-safe, lowercase-hyphens |
| short_description | text | Max ~160 chars, SEO-optimised — REQUIRED |
| description | text | Full markdown — REQUIRED |
| icon_url | text | |
| banner_url | text | First image/gif from README |
| github_url | text | Repo HTML URL |
| npm_package | text | npm package name if published |
| install_command | text | e.g. `npx @scope/package` |
| status | enum | `'draft'`/`'pending'`/`'approved'`/`'rejected'` — set `'approved'` |
| pricing | enum | `'free'`/`'freemium'`/`'paid'`/`'subscription'` — default `'free'` |
| keywords | text[] | SEO keywords |
| metadata | jsonb | See AppMetadata below |
| source_url | text | GitHub repo URL (dedup reference) |
| transport | text | Server-only: `'stdio'`/`'http'`/`'sse'` |
| tool_count | int | Server-only |
| resource_count | int | Server-only |
| prompt_count | int | Server-only |
| created_at | timestamptz | auto |
| updated_at | timestamptz | update manually on upsert |
| published_at | timestamptz | set to now() when approving |
| deleted_at | timestamptz | soft delete only |

**AppMetadata jsonb shape:**
```json
{
  "mcpCapabilities": ["resources", "tools", "prompts"],
  "supportedHosts": ["claude-desktop", "vscode-copilot", "goose"],
  "githubStars": 42,
  "githubForks": 5,
  "githubLastCommit": "2026-04-01",
  "documentationUrl": "https://...",
  "demoUrl": "https://..."
}
```

**Upsert pattern:**
```sql
INSERT INTO apps (...) VALUES (...)
ON CONFLICT (slug) DO UPDATE SET
  short_description = EXCLUDED.short_description,
  description = EXCLUDED.description,
  metadata = EXCLUDED.metadata,
  updated_at = now()
```

---

## organizations

Every app needs a publisher. Create one per GitHub owner if not found.

| Column | Type | Notes |
|--------|------|-------|
| id | uuid | PK |
| name | text | Display name |
| slug | text UNIQUE | URL-safe |
| ... | | Other fields nullable |

**Lookup or create pattern:**
```sql
INSERT INTO organizations (name, slug) VALUES ($name, $slug)
ON CONFLICT (slug) DO UPDATE SET name = EXCLUDED.name
RETURNING id
```

---

## app_categories (junction)

| Column | Type |
|--------|------|
| app_id | uuid FK → apps.id |
| category_id | uuid FK → categories.id |

---

## categories (reference)

| id | name | slug |
|----|------|------|
| c5c9c0e5-... | Data Visualization | data-visualization |
| 6fca3b5b-... | Developer Tools | developer-tools |
| 22d68606-... | Forms & Configuration | forms-configuration |
| d1fe1fab-... | Media Viewers | media-viewers |
| ce8c3244-... | Monitoring & Dashboards | monitoring-dashboards |
| ca542a3d-... | Productivity | productivity |

---

## screenshots

| Column | Type | Notes |
|--------|------|-------|
| app_id | uuid FK | |
| url | text | Image URL — REQUIRED |
| alt_text | text | Description of image |
| display_order | int | 0-indexed |
