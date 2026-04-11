---
name: ai-models-seed
description: Seeds and keeps the mcpapp-store.com ai_models table up to date with top open-source models from HuggingFace. Fetches fresh data from HF API, dedupes against DB, agent judges new candidates and writes short_description, then saves. Use when seeding the AI models leaderboard, adding new models, or running the periodic discovery cron.
---

# AI Models Seed

Keeps `ai_models` table current. Scripts handle HF API + DB; you judge candidates and write one-sentence descriptions.

## Workflow

### Regular run (pick up newly trending models)

```bash
# 1. Search HF API for new models not yet in DB
bash /home/openclaw/aimodels_search.sh

# 2. Fetch full metadata + apply transforms for candidates
bash /home/openclaw/aimodels_fetch.sh

# 3. Read /tmp/ai_models_batch.json — judge each candidate, add short_description
# 4. Write approved records to /tmp/ai_models_enriched.json
# 5. Save
bash /home/openclaw/aimodels_save.sh
```

### Add specific models by HF ID

```bash
bash /home/openclaw/aimodels_fetch.sh --ids owner/model1 owner/model2
# then enrich + save as above
```

---

## Step 2 — Your job: Judge + short_description

**search.py already filters out** quantized variants (GGUF/AWQ/GPTQ), known fine-tunes, and duplicates. But you still judge:

**Add if:**
- Distinct model family or release version with real differentiation
- From a known org (Meta, Google, Mistral, Qwen, DeepSeek, etc.)
- 1000+ likes (already pre-filtered)

**Skip if:**
- Obvious duplicate of something already in DB (e.g. same weights, different filename)
- Preview/alpha superseded by a final version already in DB
- Community fine-tune or merge

**For approved models**, fill only `short_description`:
- Max 160 chars, one sentence
- Format: `"[Provider]'s [size] [what it is] — [key strength/use case]."`
- Don't start with "A " or "An "

Write all approved records (with short_description filled) to `/tmp/ai_models_enriched.json`.

---

## Scripts

| Script | What it does |
|--------|-------------|
| `scripts/search.py` | Fetches top 150 HF text-gen models, filters quants/dupes, returns up to 5 new candidates → `/tmp/ai_models_candidates.json` |
| `scripts/fetch.py` | Fetches full HF metadata for candidates, applies all transforms (slug, variant, license, context_window, architecture, provider) → `/tmp/ai_models_batch.json` |
| `scripts/save.py` | Reads `/tmp/ai_models_enriched.json`, upserts to `ai_models` with `ON CONFLICT (slug)` |

Shell wrappers: `/home/openclaw/aimodels_search.sh`, `/home/openclaw/aimodels_fetch.sh`, `/home/openclaw/aimodels_save.sh`

---

## Cron

Run search → fetch → judge → save daily or weekly to catch newly popular models.
Suggested schedule: `0 6 * * *` (daily at 6am UTC, low cost — usually 0–5 new candidates).

## Schema reference

See `references/schema.md` for field docs, variant rules, license mappings.

## Notes

- `parameter_count` is extracted from the model name by regex — verify it for models where the name doesn't contain a size (e.g. GLM-4.5 → set manually)
- `family_slug` is derived by stripping the parameter suffix — review for unusual naming patterns
- ON CONFLICT (slug) means re-runs are safe — will update existing records
