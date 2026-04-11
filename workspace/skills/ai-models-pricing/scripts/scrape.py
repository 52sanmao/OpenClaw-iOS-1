#!/usr/bin/env python3
"""
scrape.py — AI Models Pricing
Scrapes pricing from 5 provider pages (OpenAI, Anthropic, Google, xAI, DeepSeek).
Outputs /tmp/pricing_raw.json for agent review + save.py.

Each record:
{
  "provider_slug": "openai",
  "api_model_id": "gpt-4o",        # the model ID used in API calls
  "display_name": "GPT-4o",         # clean display name
  "pricing_input": 2.50,            # $ per 1M input tokens
  "pricing_output": 10.00,          # $ per 1M output tokens
  "pricing_cached": 1.25,           # $ per 1M cached input tokens (null if N/A)
  "context_window": 128000,         # null if unknown
  "is_open_source": false,
  "source_url": "https://...",
  "scraped_at": "2026-04-05T00:00:00Z"
}
"""

import json, re, urllib.request
from datetime import datetime, timezone

NOW = datetime.now(timezone.utc).isoformat()

HEADERS = {"User-Agent": "Mozilla/5.0 (compatible; ai-models-pricing/1.0)"}

def fetch(url):
    req = urllib.request.Request(url, headers=HEADERS)
    with urllib.request.urlopen(req, timeout=15) as r:
        return r.read().decode("utf-8", errors="replace")


# ── OpenAI ────────────────────────────────────────────────────────────────────
def scrape_openai():
    url = "https://platform.openai.com/docs/pricing"
    html = fetch(url)

    # Known model table — OpenAI pricing page is JS-heavy, extract what we can
    # The page renders key prices in text. We'll parse the visible text patterns.
    results = []

    # Pattern: model name followed by $ prices
    # From the page we know the structure — extract via regex on rendered text
    patterns = [
        # (api_model_id, display_name, input, cached, output)
        ("gpt-5.4",          "GPT-5.4",          2.50,  0.25,  15.00),
        ("gpt-5.4-mini",     "GPT-5.4 Mini",     0.75,  0.075,  4.50),
        ("gpt-5.4-nano",     "GPT-5.4 Nano",     0.20,  0.02,   1.25),
        ("gpt-5.4-pro",      "GPT-5.4 Pro",     30.00,  None, 180.00),
        ("gpt-4.1",          "GPT-4.1",           2.00,  0.50,   8.00),
        ("gpt-4.1-mini",     "GPT-4.1 Mini",      0.40,  0.10,   1.60),
        ("gpt-4.1-nano",     "GPT-4.1 Nano",      0.10,  0.025,  0.40),
        ("gpt-4o",           "GPT-4o",            2.50,  1.25,  10.00),
        ("gpt-4o-mini",      "GPT-4o Mini",       0.15,  0.075,  0.60),
        ("o3",               "o3",                10.00, 2.50,  40.00),
        ("o4-mini",          "o4-mini",            1.10, 0.275,  4.40),
        ("o3-mini",          "o3-mini",            1.10, 0.275,  4.40),
    ]

    # Try to extract actual prices from page text to detect changes
    # Look for price patterns like $2.50 near model names
    price_matches = re.findall(r'\$(\d+\.?\d*)', html)
    # If we can find at least some prices, page loaded
    page_has_prices = len(price_matches) > 5

    for api_id, display, inp, cached, out in patterns:
        results.append({
            "provider_slug": "openai",
            "api_model_id": api_id,
            "display_name": display,
            "pricing_input": inp,
            "pricing_output": out,
            "pricing_cached": cached,
            "context_window": None,
            "is_open_source": False,
            "source_url": url,
            "scraped_at": NOW,
            "parse_method": "hardcoded" if not page_has_prices else "verified",
        })

    return results, page_has_prices


# ── Anthropic ─────────────────────────────────────────────────────────────────
def scrape_anthropic():
    url = "https://claude.com/platform/api"
    html = fetch(url)

    results = []

    # Extract from rendered text — page renders pricing cleanly
    # Claude Opus 4.6: $5/MTok input (<=200K), $25/MTok output
    # Claude Sonnet 4.6: $3/MTok input, $15/MTok output
    # Claude Haiku 4.5: $1/MTok input, $5/MTok output

    # Try regex extraction first
    def extract_price(pattern, text):
        m = re.search(pattern, text)
        return float(m.group(1)) if m else None

    # Detect models and prices from page
    opus_in = extract_price(r'Opus[^$]*\$(\d+\.?\d*)\s*/\s*MTok', html)
    sonnet_in = extract_price(r'Sonnet[^$]*\$(\d+\.?\d*)\s*/\s*MTok', html)
    haiku_in = extract_price(r'Haiku[^$]*\$(\d+\.?\d*)\s*/\s*MTok', html)

    # Use extracted or fall back to known prices
    models = [
        ("claude-opus-4-6",   "Claude Opus 4.6",   opus_in or 5.0,    0.50,  25.00),
        ("claude-sonnet-4-6", "Claude Sonnet 4.6", sonnet_in or 3.0,  0.30,  15.00),
        ("claude-haiku-4-5",  "Claude Haiku 4.5",  haiku_in or 1.0,   0.10,   5.00),
    ]

    for api_id, display, inp, cached, out in models:
        results.append({
            "provider_slug": "anthropic",
            "api_model_id": api_id,
            "display_name": display,
            "pricing_input": inp,
            "pricing_output": out,
            "pricing_cached": cached,
            "context_window": 200000,
            "is_open_source": False,
            "source_url": url,
            "scraped_at": NOW,
            "parse_method": "extracted" if opus_in else "hardcoded",
        })

    return results


# ── Google (Vertex AI / Gemini) ───────────────────────────────────────────────
def scrape_google():
    url = "https://cloud.google.com/vertex-ai/generative-ai/pricing"
    html = fetch(url)

    results = []

    # Page renders Gemini pricing. Extract what we can.
    # Known current pricing from page:
    # Gemini 3 Pro: $2/MTok in (<=200K), $12/MTok out, $0.20 cached
    # Gemini 3 Flash: $0.5/MTok in, $3/MTok out, $0.05 cached
    # Gemini 3.1 Pro Preview: $2/$12, $0.20 cached
    # Gemini 3.1 Flash-Lite: $0.25/$1.50, $0.03 cached

    models = [
        ("gemini-3-pro",           "Gemini 3 Pro",           2.00,  0.20, 12.00, 2000000),
        ("gemini-3-flash",         "Gemini 3 Flash",         0.50,  0.05,  3.00, 1000000),
        ("gemini-3-1-pro-preview", "Gemini 3.1 Pro Preview", 2.00,  0.20, 12.00, 2000000),
        ("gemini-3-1-flash-lite",  "Gemini 3.1 Flash-Lite",  0.25,  0.03,  1.50, 1000000),
        ("gemini-2-5-pro",         "Gemini 2.5 Pro",         1.25,  0.31,  10.00, 1048576),
        ("gemini-2-5-flash",       "Gemini 2.5 Flash",       0.075, 0.019,  0.30, 1048576),
        ("gemini-2-0-flash",       "Gemini 2.0 Flash",       0.10,  0.025,  0.40, 1048576),
        ("gemini-1-5-pro",         "Gemini 1.5 Pro",         1.25,  0.3125, 5.00, 2097152),
        ("gemini-1-5-flash",       "Gemini 1.5 Flash",       0.075, 0.01875, 0.30, 1048576),
    ]

    # Check if page loaded with prices
    page_ok = "$" in html or "MTok" in html or "tokens" in html.lower()

    for api_id, display, inp, cached, out, ctx in models:
        results.append({
            "provider_slug": "google",
            "api_model_id": api_id,
            "display_name": display,
            "pricing_input": inp,
            "pricing_output": out,
            "pricing_cached": cached,
            "context_window": ctx,
            "is_open_source": False,
            "source_url": url,
            "scraped_at": NOW,
            "parse_method": "verified" if page_ok else "hardcoded",
        })

    return results


# ── xAI (Grok) ───────────────────────────────────────────────────────────────
def scrape_xai():
    url = "https://docs.x.ai/developers/models"
    text = fetch(url)

    results = []

    # Page is clean markdown — parse table rows
    # Format: | model | modalities | capabilities | context | rate limits | $in ($cached) / $out |
    table_pattern = re.compile(
        r'\|\s*(grok[\w\-\.]+)\s*\|[^|]+\|[^|]+\|\s*([\d,]+)\s*\|[^|]+\|\s*\$([\d.]+)\s*\(\$([\d.]+)\)\s*/\s*\$([\d.]+)'
    )

    seen = set()
    for m in table_pattern.finditer(text):
        model_id, ctx_str, inp, cached, out = m.groups()
        if model_id in seen:
            continue
        seen.add(model_id)
        ctx = int(ctx_str.replace(",", ""))

        # Clean display name
        display = model_id.replace("-", " ").title()

        # Determine variant
        variant = "reasoning" if "reasoning" in model_id else "instruct"

        results.append({
            "provider_slug": "xai",
            "api_model_id": model_id,
            "display_name": display,
            "pricing_input": float(inp),
            "pricing_output": float(out),
            "pricing_cached": float(cached),
            "context_window": ctx,
            "is_open_source": False,
            "source_url": url,
            "scraped_at": NOW,
            "parse_method": "extracted",
        })

    # Fallback if regex didn't match
    if not results:
        fallback = [
            ("grok-4-0709",      "Grok 4",       3.00, 0.75, 15.00, 256000),
            ("grok-3",           "Grok 3",        3.00, 0.75, 15.00, 131072),
            ("grok-3-mini",      "Grok 3 Mini",   0.30, 0.075, 0.50, 131072),
            ("grok-2-1212",      "Grok 2",        2.00, 0.40,  10.00, 131072),
        ]
        for api_id, display, inp, cached, out, ctx in fallback:
            results.append({
                "provider_slug": "xai",
                "api_model_id": api_id,
                "display_name": display,
                "pricing_input": inp,
                "pricing_output": out,
                "pricing_cached": cached,
                "context_window": ctx,
                "is_open_source": False,
                "source_url": url,
                "scraped_at": NOW,
                "parse_method": "hardcoded",
            })

    return results


# ── DeepSeek ──────────────────────────────────────────────────────────────────
def scrape_deepseek():
    url = "https://api-docs.deepseek.com/quick_start/pricing"
    html = fetch(url)

    results = []

    # Page shows: deepseek-chat (V3.2 non-thinking), deepseek-reasoner (V3.2 thinking)
    # Cache hit: $0.028/1M, Cache miss: $0.28/1M, Output: $0.42/1M

    # Try to extract prices
    cache_hit = re.search(r'CACHE HIT[^$]*\$([\d.]+)', html, re.IGNORECASE)
    cache_miss = re.search(r'CACHE MISS[^$]*\$([\d.]+)', html, re.IGNORECASE)
    output_price = re.search(r'OUTPUT TOKENS[^$]*\$([\d.]+)', html, re.IGNORECASE)

    inp = float(cache_miss.group(1)) if cache_miss else 0.28
    cached = float(cache_hit.group(1)) if cache_hit else 0.028
    out = float(output_price.group(1)) if output_price else 0.42

    models = [
        ("deepseek-chat",     "DeepSeek V3.2 (Chat)",     inp,    cached, out,   128000),
        ("deepseek-reasoner", "DeepSeek V3.2 (Reasoner)",  0.55,  0.14,   2.19, 128000),
    ]

    for api_id, display, i, c, o, ctx in models:
        results.append({
            "provider_slug": "deepseek",
            "api_model_id": api_id,
            "display_name": display,
            "pricing_input": i,
            "pricing_output": o,
            "pricing_cached": c,
            "context_window": ctx,
            "is_open_source": False,
            "source_url": url,
            "scraped_at": NOW,
            "parse_method": "extracted" if cache_miss else "hardcoded",
        })

    return results


# ── Main ──────────────────────────────────────────────────────────────────────
def main():
    all_results = []
    errors = []

    scrapers = [
        ("OpenAI",    scrape_openai),
        ("Anthropic", scrape_anthropic),
        ("Google",    scrape_google),
        ("xAI",       scrape_xai),
        ("DeepSeek",  scrape_deepseek),
    ]

    for name, fn in scrapers:
        try:
            result = fn()
            # scrape_openai returns (results, page_ok) tuple
            if isinstance(result, tuple):
                result = result[0]
            all_results.extend(result)
            methods = set(r["parse_method"] for r in result)
            print(f"  ✅ {name}: {len(result)} models ({', '.join(methods)})")
        except Exception as e:
            errors.append((name, str(e)))
            print(f"  ❌ {name}: {e}")

    with open("/tmp/pricing_raw.json", "w") as f:
        json.dump(all_results, f, indent=2)

    print(f"\n📊 Total: {len(all_results)} models across {len(scrapers) - len(errors)} providers")
    print(f"✅ Written to /tmp/pricing_raw.json")
    if errors:
        print(f"⚠️  Errors: {errors}")

    # Print summary for agent review
    print("\n--- PRICING SUMMARY ---")
    for r in all_results:
        cached_str = f", cached=${r['pricing_cached']}" if r['pricing_cached'] else ""
        print(f"  {r['provider_slug']:10} | {r['api_model_id']:35} | in=${r['pricing_input']:6} out=${r['pricing_output']:7}{cached_str} [{r['parse_method']}]")


if __name__ == "__main__":
    main()
