---
name: ai-models-pricing
description: Scrapes paid AI provider pricing pages (OpenAI, Anthropic, Google, xAI, DeepSeek) and updates pricing_input/pricing_output/pricing_cached fields in the mcpapp-store.com ai_models table. Also inserts new paid models not yet in DB. Use when running the weekly pricing update, when a provider announces new models or price changes, or when pricing data in DB looks stale.
---

# AI Models Pricing

Keeps `pricing_input`, `pricing_output`, `pricing_cached` current in `ai_models`. Scripts scrape 5 providers; agent reviews and flags any `hardcoded` results for web search verification.

## Workflow

```bash
# 1. Scrape all providers
bash /home/openclaw/aimodels_scrape_pricing.sh

# 2. Review /tmp/pricing_raw.json output printed to stdout
#    ⚠️  If any model shows [hardcoded] — verify price via web search before saving

# 3. Save to DB
bash /home/openclaw/aimodels_pricing_save.sh
```

## Your job — review step

Check the stdout summary after scraping. Each line shows:
```
provider | api_model_id | in=$X out=$Y [method]
```

- `[extracted]` or `[verified]` — trust it, save as-is
- `[hardcoded]` — page didn't render prices; web search to confirm before saving
  - Search: `"openai gpt-4o pricing per million tokens 2026"`
  - Update `/tmp/pricing_raw.json` if prices have changed, then save

## Providers covered

| Provider | URL | Status |
|---|---|---|
| OpenAI | platform.openai.com/docs/pricing | ✅ scraped |
| Anthropic | claude.com/platform/api | ✅ scraped |
| Google | cloud.google.com/vertex-ai/generative-ai/pricing | ✅ scraped |
| xAI | docs.x.ai/developers/models | ✅ scraped (clean markdown) |
| DeepSeek | api-docs.deepseek.com/quick_start/pricing | ✅ scraped |
| Mistral | — | ⚠️ web search only |

For Mistral: search `"mistral api pricing {year} per million tokens"` and manually add to `/tmp/pricing_raw.json` before saving.

## Scripts

- `scripts/scrape.py` → `/tmp/pricing_raw.json`
- `scripts/save.py` ← reads `/tmp/pricing_raw.json`, upserts DB

Shell wrappers: `/home/openclaw/aimodels_scrape_pricing.sh`, `/home/openclaw/aimodels_pricing_save.sh`

## Provider details & model IDs

See `references/providers.md` for full model ID lists, confirmed URLs, and DB matching strategy.
