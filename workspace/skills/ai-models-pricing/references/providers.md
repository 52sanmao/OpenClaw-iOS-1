# Providers Reference

## Confirmed working URLs

| Provider | URL | Method | Notes |
|---|---|---|---|
| OpenAI | `https://platform.openai.com/docs/pricing` | scrape | JS-heavy, prices in text |
| Anthropic | `https://claude.com/platform/api` | scrape | renders cleanly |
| Google | `https://cloud.google.com/vertex-ai/generative-ai/pricing` | scrape | Vertex AI = Gemini API prices |
| xAI | `https://docs.x.ai/developers/models` | scrape | clean markdown table, fully parsed |
| DeepSeek | `https://api-docs.deepseek.com/quick_start/pricing` | scrape | minimal page, easy to parse |
| Mistral | `https://docs.mistral.ai/getting-started/models` | web search | no per-token table, use web search |

## Per-provider model IDs (API names)

### OpenAI
- `gpt-5.4`, `gpt-5.4-mini`, `gpt-5.4-nano`, `gpt-5.4-pro`
- `gpt-4.1`, `gpt-4.1-mini`, `gpt-4.1-nano`
- `gpt-4o`, `gpt-4o-mini`
- `o3`, `o4-mini`, `o3-mini`

### Anthropic
- `claude-opus-4-6` (Opus 4.6) — $5/$25 per MTok
- `claude-sonnet-4-6` (Sonnet 4.6) — $3/$15 per MTok
- `claude-haiku-4-5` (Haiku 4.5) — $1/$5 per MTok

### Google (Vertex / Gemini API)
- `gemini-3-pro`, `gemini-3-flash`, `gemini-3-1-pro-preview`, `gemini-3-1-flash-lite`
- `gemini-2-5-pro`, `gemini-2-5-flash`
- `gemini-2-0-flash`
- `gemini-1-5-pro`, `gemini-1-5-flash`

### xAI
- `grok-4.20-0309-reasoning` / `grok-4.20-0309-non-reasoning` — $2.00/$6.00
- `grok-4-1-fast-reasoning` / `grok-4-1-fast-non-reasoning` — $0.20/$0.50
- `grok-4-0709` — latest stable Grok 4

### DeepSeek
- `deepseek-chat` = DeepSeek-V3.2 non-thinking — $0.28 in / $0.42 out (cache hit $0.028)
- `deepseek-reasoner` = DeepSeek-V3.2 thinking — $0.55 in / $2.19 out

### Mistral (web search fallback)
Search: `"mistral api pricing {current_year} mistral-large codestral per million tokens"`
Key models: `mistral-large-2411`, `mistral-small-2503`, `codestral-2501`, `magistral-medium-2507`

## DB matching strategy

`save.py` matches scraped `api_model_id` against DB rows using:
1. `hf_model_id` column (for open-source models that also have API access e.g. DeepSeek)
2. `slug` column (normalized api_model_id)

If no match → inserts as new paid model row.

## Pricing fields in ai_models table

- `pricing_input` — $ per 1M input tokens (standard)
- `pricing_output` — $ per 1M output tokens
- `pricing_cached` — $ per 1M cached input tokens (null if provider doesn't offer caching)

All prices stored as float, USD per 1M tokens.

## Parse methods

- `extracted` — regex parsed from live page (most reliable)
- `verified` — page loaded and had price content, used hardcoded values
- `hardcoded` — page didn't load properly, used known prices (⚠️ may be stale)

When the agent sees `hardcoded` results in the summary, do a web search to verify current prices before saving.
