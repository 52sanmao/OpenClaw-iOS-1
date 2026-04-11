---
name: seo-ctr-optimiser
description: Weekly SEO cron skill that improves click-through rates on a client site. Pulls low-CTR pages from Google Search Console (high impressions, low CTR), checks a SQL DB for grace periods, generates improved title/description using real query data, updates MDX frontmatter or TSX metadata, pushes directly to main, and records everything in the DB. Use when running the weekly CTR optimisation pass or when manually triggering a CTR audit.
---

# SEO CTR Optimiser

Improves page CTR by rewriting titles/descriptions using real GSC query data. Tracks all changes in a SQL DB with 28-day grace periods.

## Key Files

- `scripts/gsc_low_ctr.py` — pulls low-CTR pages + top queries from GSC
- `scripts/db.py` — PostgREST DB client (get/upsert/list/setup — works with any PostgREST backend)
- `scripts/update_frontmatter.py` — updates MDX blog post seo fields
- `scripts/update_tsx_metadata.py` — updates TSX page metadata
- `scripts/skill_config.py` — shared config loader (all scripts import this)

## Config

All site-specific values live in `~/.config/seo-ctr-optimiser/config.json`.
On first run, if missing, scripts auto-copy `references/config.example.json` and exit with instructions.

**For a new client deployment — edit these fields:**
- `site_domain`, `site_url`, `gsc_site` — client's domain
- `repo_path` — local path to the client's git repo
- `blog_content_path` — relative path to blog MDX files inside repo
- `tsx_pages` — map of slug → TSX file path (Next.js only; omit for non-Next.js sites)
- `locked_title_prefixes` — any slugs with a required title prefix (e.g. brand name)
- `skip_paths` — URL paths to never touch (policy pages etc.)

**DB:** `~/.config/supabase/config.json` — url (PostgREST base), postgres_url, anon_key, service_role_key
**DB table:** `ctr_pages` — run `python3 scripts/db.py setup` on first install (idempotent)
**Grace period:** 28 days — do not re-optimise until expired
**Max changes per run:** 2 pages (keeps cause/effect traceable)

## SEO Character Limits (enforce strictly)

| Field | Target | Hard Max | Why |
|---|---|---|---|
| Title | 50–60 chars | 60 chars | Google truncates at ~60 |
| Description | 145–155 chars | 160 chars | Google truncates at ~155–160 |

Always count characters before finalising. Short and punchy beats long and truncated.

## Page Types

| Page | Slug | Type | Constraint |
|---|---|---|---|
| Homepage | `homepage` | TSX | Locked prefix from `locked_title_prefixes` in config |
| Other TSX pages | per `tsx_pages` in config | TSX | None |
| Blog posts | `<post-slug>` | MDX | None |

TSX pages: use `update_tsx_metadata.py`. MDX posts: use `update_frontmatter.py`.
Skip: paths listed in `skip_paths` in config. Skip subdomains not in the main repo.

## Workflow

### Step 1 — Pull GSC data

```bash
python3 scripts/gsc_low_ctr.py --limit 10 --min-impressions 50 --max-ctr 0.03
```

Returns JSON sorted by impressions DESC. Each item: `slug`, `url`, `page_type`, `impressions`, `ctr_pct`, `position`, `top_queries[]`.

**Position filter:** Skip if top query position > 40. Use top query position, not page average — averages are dragged down by long-tail noise. If empty → report "No pages qualify" and stop.

### Step 2 — Check DB for each candidate

```bash
python3 scripts/db.py get <slug>
```

- **No row / Status = Pending** → eligible
- **Status = Changed** + before `grace_period_until` → SKIP (update GSC data only, don't rewrite)
- **Status = Changed** + grace period passed → re-evaluate (did CTR improve?)
- **Status = Stable / GiveUp** → skip

Pick top 2 eligible by impressions. If zero → report grace period expiry dates and stop.

### Step 3 — Read current title + description

TSX: read the relevant `src/app/.../page.tsx` (from `tsx_pages` config). Extract `title:` and `description:`.
MDX: read `<blog_content_path>/<slug>.md`. Extract `seo.title` and `seo.description` from frontmatter.

### Step 4 — Generate improved title + description

Use real GSC query data. Look at top 5–10 queries, group by intent.

**Title rules (50–60 chars hard max):**
- Lead with primary keyword (highest impression query)
- Apply locked prefix from config if set for this slug
- Use `|` to separate concepts, not ` - ` (saves chars)
- Count the characters — be exact

**Description rules (145–155 chars, hard max 160):**
- Open with primary keyword in first 10 words
- Weave in 2–3 secondary query terms naturally
- End with concrete value prop or CTA ("Free 30-min call")
- UK spelling (specialising, not specializing)
- Count the characters — be exact

If current title/description already meets the rules → skip, don't change for change's sake.

**Re-evaluation (grace period passed):** Compare current CTR to CTR at last change (in DB). Improved → mark Stable. Same/worse → rewrite with different angle.

### Step 5 — Update the file

```bash
python3 scripts/update_tsx_metadata.py <slug> --title "..." --description "..."
python3 scripts/update_frontmatter.py <slug> --title "..." --description "..."
```

Both print a diff — verify before committing.

### Step 6 — Git commit and push

```bash
cd $REPO_PATH  # from config
git pull && git add <changed file> && git commit -m "seo: improve CTR for <slug>

Impressions: <N> | CTR: <X>% | Pos: <Y>
Top queries: <q1>, <q2>
Old title (<N>c): <old> | New title (<N>c): <new>
Old desc (<N>c): <old> | New desc (<N>c): <new>" && git push origin main
```

Use `GH_CONFIG_DIR=~/.openclaw/gh`. Push directly to main.

### Step 7 — Update DB

```bash
echo '{"slug":"<slug>","status":"Changed","current_title":"...","previous_title":"...","impressions":N,"ctr_pct":X,"avg_position":Y,"top_queries":"q1, q2","last_changed":"YYYY-MM-DD","grace_period_until":"YYYY-MM-DD","times_optimised":N,"notes":"..."}' | python3 scripts/db.py upsert
```

For skipped grace-period pages — update GSC data only (impressions, ctr_pct, top_queries, notes).

### Step 8 — Telegram summary

Send summary to the user via `message` tool (channel=telegram):

```
📈 CTR Optimiser — <date>

Changed (N):
• <slug>: <X>% CTR | <N> impr | pos <Y>
  Title (<Nc>): "..."
  Desc (<Nc>): "..."

Watching — grace period active (N):
• <slug>: until <date>
```

## Status Reference

| Status | Meaning |
|---|---|
| Pending | In GSC, not yet optimised |
| Changed | Updated, waiting 28 days |
| Watching | Grace period passed — re-evaluating |
| Stable | CTR improved — leave it alone |
| GiveUp | 3+ attempts, no improvement |
