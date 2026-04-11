---
name: news-aggregator
description: >-
  Fetches AI/MCP news from configured sources (RSS + scraping), enriches items
  with agent-written summaries, saves to mcpapp-store.com database, and
  generates temporal digests (daily/weekly/monthly/quarterly). One source at a
  time. Start with claude-blog, add more sources incrementally.
---

# News Aggregator — Enrichment

Collects AI/MCP news from sources one by one, judges quality, writes clean summaries, and saves to the DB.

---

## Cron workflow (automated runs)

Each cron run checks **all active sources** for new items, collects up to 5, and enriches them. Simple.

### Step 1 — Fetch from all sources

```bash
python3 /home/openclaw/.openclaw/workspace/skills/news-aggregator/scripts/news_fetch.py --limit 5 --since 2026-01-01
```

This checks every active source, deduplicates against the DB, and returns up to 5 new items total across all sources.

**If the output is `[]` — stop. Nothing to do. Exit cleanly. Do not write any files or call save.sh.**

For **huggingface-blog** specifically: add `--no-og` and handle images manually (see gotcha). For the cron, it's simplest to just run without `--no-og` and accept that HF items come with no image initially — they can be backfilled.

### Step 2 — Judge and enrich

For each item in the array (max 5) — apply judgment rules below. Write enriched JSON.

### Step 3 — Save

```bash
python3 /home/openclaw/.openclaw/workspace/skills/news-aggregator/scripts/news_save.py
```

Saved items (enriched + skipped) are recorded in DB so they never reappear.

---

## Manual workflow (one-off runs)

To run a specific source manually:

```bash
python3 /home/openclaw/.openclaw/workspace/skills/news-aggregator/scripts/news_fetch.py --source claude-blog
python3 /home/openclaw/.openclaw/workspace/skills/news-aggregator/scripts/news_fetch.py --source openai-news --since 2026-01-01 --no-og --limit 8
python3 /home/openclaw/.openclaw/workspace/skills/news-aggregator/scripts/news_fetch.py --list-sources   # list all sources + last fetch times
```

Seed sources (first time only):

```bash
python3 /home/openclaw/.openclaw/workspace/skills/news-aggregator/scripts/news_seed.py
```

---

## Fetch flags

| Flag | Default | Use |
|---|---|---|
| `--source <slug>` | oldest unchecked | Target a specific source |
| `--limit N` | 8 | Max items per run (keep ≤ 10) |
| `--since YYYY-MM-DD` | none | Filter to items newer than date (use for high-volume RSS) |
| `--no-og` | off | Skip OG meta fetch (use for HF blog — judge by title first) |
| `--list-sources` | — | List sources with last fetch time |

---

## Fetch output fields

Each item in the JSON array:
- `source_id` — UUID, **passthrough, required**
- `source_name` — display name
- `title` — raw title from source
- `url` — full article URL
- `raw_description` — RSS description or null
- `og_description` — from og:description (often boilerplate — see per-source gotchas)
- `og_image` — from og:image meta tag
- `published_at` — ISO timestamp or null
- `category` — from RSS category field or null

---

## Judgment rules

**SAVE if:**
- Genuine product announcement, research finding, or industry development
- Something a developer or AI practitioner would actually care about
- New capability, model release, tool launch, or important partnership

**SKIP (`"skip": true`) if:**
- Pure marketing / event invite / job listing
- Duplicate of something already covered (same story, different framing)
- Narrow vendor-specific content with no broad relevance
- Paywall-only with no useful summary

**For SAVE items, write:**
- `summary` — 2-3 clean sentences. What happened, why it matters. Write for a developer. Don't start "In this post..." and don't copy `og_description` verbatim.
- `image_url` — use `og_image` if present; null if not available (never fabricate)
- `tags` — 3-8 lowercase strings (e.g. `mcp`, `claude`, `agents`, `model-release`, `developer-tools`)
- `status` — always `"enriched"`

**Passthrough (copy exactly, don't modify):**
```
source_id, title, url, published_at
```

**For SKIP items:** `{ "skip": true, "url": "...", "source_id": "...", "title": "..." }` — skipped URLs are saved to DB so they never re-appear.

---

## Priority topics (always save these)

- **MCP** — spec updates, new servers/clients, ecosystem news, integrations
- **Agent Skills** — SKILL.md packages, agent tooling, skill ecosystems
- **New model announcements** — GPT-x, Claude x, Gemini x, Llama x, Mistral, etc.
- **New AI developer tools** — SDKs, APIs, frameworks, libraries
- **New features** — Claude, ChatGPT, Gemini, Copilot, Cursor (especially agentic/coding)
- **Agent frameworks** — LangChain, CrewAI, AutoGen, OpenAI Agents SDK, etc.
- **AI coding tools** — anything in AI-assisted development

**Also save:** significant research with practical implications, major ecosystem moves, funding rounds for notable AI companies.

---

## Per-source gotchas

**claude-blog** (`https://claude.com/blog`)
- No RSS. Scraper reads actual `<a href>` slugs from the page — **never constructs slugs from titles**.
- Anthropic uses short custom slugs (e.g. `/blog/auto-mode`, `/blog/1m-context-ga`) that don't match title text.
- ⚠️ **Bug fixed Apr 2026:** Old scraper was generating slugs from titles (wrong). 14 items had broken URLs fixed when scraper was corrected.
- OG fetch required for title, date, image (listing shows href only).
- Some articles have no OG image — leave null.
- Slug construction is accurate (~95%), confirmed by testing.
- Some articles have no OG image on Anthropic's servers — leave null.

**anthropic-engineering** (`https://www.anthropic.com/engineering`)
- No RSS. Exact slugs from `<a href>` tags.
- Featured article at top has NO date in static HTML (JS-rendered). Fix: web search for publish date.
- Scraper strips "Featured" prefix and truncates title/description bleed.

**openai-dev-blog** (`https://developers.openai.com/blog`)
- No RSS. Date prefix format `Mon DDTitle...Category` in link text.
- Featured links appear WITHOUT dates at top, then WITH dates below — dedup fixed by only processing date-prefixed links.
- Skip `/blog/topic/` links and the `/blog/intro` hello world post.
- Titles sometimes bleed into description — use `og_description` to get clean title when enriching.

**openai-news** (`https://openai.com/news`) — RSS at `https://openai.com/news/rss.xml`
- 903 items in feed. **Always use `--since 2026-01-01`**.
- URLs use `/index/slug` pattern (not `/news/slug`).
- **~50% skip rate** — heavy filtering required.
- **Skip by category:** B2B Story, Global Affairs, Brand Story, AI Adoption, most Company posts.
- **Skip selectively:** Safety (only if developer-relevant), Publication (system cards — only landmark ones).
- Skipped items saved to DB with `status='skipped'` — won't reappear.

**mcp-blog** (`https://blog.modelcontextprotocol.io/posts/`) — RSS at `posts/index.xml`
- Low volume (19 posts), ~100% signal. Skip only the "welcome to the blog" intro post.
- All posts share the same default `og-image.png` — no per-article images, expected, leave as-is.
- RSS descriptions are clean — use `raw_description` as summary base, rewrite into 2-3 sentences.
- No `--since` filter needed.

**google-developers** ("Google AI Blog", `https://blog.google/innovation-and-ai/technology/developers-tools/`) — RSS at `<url>/rss/`
- ⚠️ **URL migration (Apr 2026):** Google moved this section from `/technology/developers/` to `/innovation-and-ai/technology/developers-tools/`. DB source URL and all item URLs updated. If items 404 again, check if Google has moved the section again.
- **Images come from `media:content` in RSS** — no OG fetch needed, images pre-populated automatically. All 20 items have images.
- **Google blog has many sections, each with its own RSS** at `<section-url>/rss/`. The developers section is the most relevant for our audience. Other sections (`/innovation-and-ai/`, `/products/gemini/`) overlap heavily.
- **~50% skip rate** — skip: monthly AI recaps, event invites (I/O save-the-date, challenge hosting), music/video generation posts (Lyria, Veo), design tool announcements.
- **Save:** Gemini API updates, new Gemini model variants, MCP integrations, agent frameworks, coding tools, embedding models.
- Only 20 items in feed — no `--since` needed.
- Ghost CMS. Only **15 items** in feed (Ghost default limit) — small, no `--since` needed.
- Clean descriptions in RSS — use `raw_description` as summary base, but **some items have raw HTML** (Ghost callout cards, `<div>` wrappers). Strip HTML and use the text content only.
- **~30% skip rate.** Skip: newsletters, event invites, Partner Post category, Case Studies category.
- Save: engineering posts, product launches, research, evals, agent patterns.
- `og_description` sometimes cleaner than `raw_description` for HTML-heavy items — use whichever is cleaner.
- No RSS. Exact slugs from `<a href>` tags. Date format: `"Apr 2, 2026 · Product Title..."`.
- Customer story posts (`/blog/planetscale`, `/blog/nvidia`, etc.) have no date prefix — automatically skipped by scraper.
- Titles sometimes bleed author/read-time (`"Author 7m Author · 7m"`) — scraper strips this, but use `og_description` as title reference when enriching if title looks wrong.
- OG images are **animated GIFs** — real, specific, high quality. Always save them.
- ~100% signal — Cursor only posts substantial product and research content.
- Skip: customer case studies (no date prefix, auto-filtered). Save everything else.
- 756 items, ~43 since Jan 2026. **Always use `--since 2026-01-01 --no-og`**.
- **RSS has NO descriptions** — titles only. Judge by title alone on first pass.
- **`og:description` is boilerplate** ("We're on a journey..." or "A Blog post by X") — ignore entirely.
- **OG images ARE specific and useful** — after judging which items to save, fetch their OG images manually and include in enriched output.
- **~50% skip rate.** Skip: narrow vendor model releases (Falcon, Granite, etc.), robotics, diffusion, narrow research, tutorials without broad applicability.
- **Save:** major model releases (Gemma, Llama, etc.), agent evals/frameworks, HF platform features, open-source ecosystem analysis, developer tooling.

---

## Reference

See `references/db-schema.md` for full table definitions and key queries.
