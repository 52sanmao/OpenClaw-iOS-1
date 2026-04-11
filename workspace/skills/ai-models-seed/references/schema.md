# AI Models — DB Schema & Transform Rules

## ai_models table (key fields)

| Field | Type | Notes |
|-------|------|-------|
| `slug` | text PK | URL-safe, hyphen-case, max 80 chars. Unique constraint — used for ON CONFLICT upsert. |
| `name` | text | Display name from HF model ID, underscores → hyphens |
| `provider` | text | Human display name e.g. "Mistral AI", "Meta", "DeepSeek AI" |
| `provider_slug` | text | e.g. "mistral", "meta", "deepseek" |
| `short_description` | text | 1 sentence, ≤160 chars — **agent writes this** |
| `is_open_source` | bool | true for all HF models (unless license=proprietary) |
| `license` | text | Cleaned license string (see mappings below) |
| `family_slug` | text | From tier1 data e.g. "llama-3.1", "deepseek-r1" |
| `variant` | text | base / instruct / reasoning / code |
| `parameter_count` | text | e.g. "7B", "671B" — stored as string |
| `hf_model_id` | text | e.g. "meta-llama/Llama-3.1-8B-Instruct" |
| `modalities_input` | text[] | ["text"] or ["text","image"] for vision models |
| `modalities_output` | text[] | ["text"] always |
| `context_window` | int | Token limit (see lookup below) |
| `architecture` | text | "Transformer" or "MoE" |
| `is_active` | bool | Always true |
| `is_featured` | bool | true if likes >= 2000 |
| `source_url` | text | https://huggingface.co/{hf_model_id} |
| `model_card_url` | text | Same as source_url |
| `arena_elo` | int | Null until Arena AI data added |
| `composite_score` | float | Null until benchmark data added |

## License mappings

| Raw | Display |
|-----|---------|
| apache-2.0 | Apache 2.0 |
| mit | MIT |
| llama3 | Llama 3 Community |
| llama3.1 | Llama 3.1 Community |
| llama2 | Llama 2 Community |
| bigscience-bloom-rail-1.0 | BLOOM RAIL 1.0 |
| gemma | Gemma Terms |
| unknown | Proprietary |

## Variant overrides (applied in fetch.py)

These models have wrong variants in tier1 data — corrected automatically:

| HF ID | Correct variant |
|-------|----------------|
| deepseek-ai/DeepSeek-V3 | instruct |
| deepseek-ai/DeepSeek-V3-0324 | instruct |
| deepseek-ai/DeepSeek-V3.2 | instruct |
| openai/gpt-oss-120b | instruct |
| openai/gpt-oss-20b | instruct |
| moonshotai/Kimi-K2-Thinking | reasoning |
| HuggingFaceH4/zephyr-7b-beta | instruct |
| openchat/openchat_3.5 | instruct |

## Context windows (applied in fetch.py)

| Family slug contains | Context window |
|---------------------|---------------|
| llama-3.1 / 3.2 / 3.3 | 131072 |
| deepseek-r1 / deepseek-v3 | 163840 |
| phi-4 | 16384 |
| phi-3-mini-128k | 131072 |
| gpt-2 | 1024 |
| gpt-oss | 131072 |
| bloom / falcon | 2048 |
| qwq-32b | 131072 |
| kimi-k2 | 131072 |
| mixtral | 32768 |
| gemma-2 / gemma-3 | 8192 |

## Skipped models (community fine-tunes)

These are permanently excluded in fetch.py:
- `mattshumer/Reflection-Llama-3.1-70B`
- `dphn/dolphin-2.5-mixtral-8x7b`

## Vision detection

Models with `-VL`, `-vision`, `llava`, `-mm`, or `multimodal` in their HF ID get `modalities_input: ["text", "image"]`.
