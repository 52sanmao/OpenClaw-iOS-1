#!/usr/bin/env python3
"""
fetch.py — AI Models Seed
Given a list of candidate hf_model_ids (from search.py output or manual list),
fetches full metadata from HF API and applies all mechanical transforms.
Outputs enriched records to /tmp/ai_models_batch.json — agent adds short_description only.

Usage:
  python3 fetch.py                          # reads /tmp/ai_models_candidates.json
  python3 fetch.py --ids owner/model1 ...   # fetch specific model IDs
"""

import json, re, sys, urllib.request, argparse
from datetime import datetime, timezone

INPUT_PATH = "/tmp/ai_models_candidates.json"
OUTPUT_PATH = "/tmp/ai_models_batch.json"

# ── License mappings ──────────────────────────────────────────────────────────
LICENSE_MAP = {
    "apache-2.0": "Apache 2.0",
    "mit": "MIT",
    "llama3": "Llama 3 Community",
    "llama3.1": "Llama 3.1 Community",
    "llama3.2": "Llama 3.2 Community",
    "llama3.3": "Llama 3.3 Community",
    "llama2": "Llama 2 Community",
    "bigscience-bloom-rail-1.0": "BLOOM RAIL 1.0",
    "cc-by-nc-4.0": "CC BY-NC 4.0",
    "cc-by-nc-nd-4.0": "CC BY-NC-ND 4.0",
    "gpl-3.0": "GPL 3.0",
    "gemma": "Gemma Terms",
    "unknown": "Proprietary",
    "other": "Other",
}

# ── Variant detection ─────────────────────────────────────────────────────────
VARIANT_OVERRIDES = {
    "deepseek-ai/DeepSeek-V3": "instruct",
    "deepseek-ai/DeepSeek-V3-0324": "instruct",
    "deepseek-ai/DeepSeek-V3.2": "instruct",
    "openai/gpt-oss-120b": "instruct",
    "openai/gpt-oss-20b": "instruct",
    "moonshotai/Kimi-K2-Thinking": "reasoning",
    "HuggingFaceH4/zephyr-7b-beta": "instruct",
    "openchat/openchat_3.5": "instruct",
}

def detect_variant(hf_id):
    if hf_id in VARIANT_OVERRIDES:
        return VARIANT_OVERRIDES[hf_id]
    name = hf_id.lower()
    if any(x in name for x in ["-instruct", "-chat", "-it", "-sft", "-rlhf", "-dpo", "-command"]):
        return "instruct"
    if any(x in name for x in ["-thinking", "-r1", "qwq", "-reason", "-distill"]):
        return "reasoning"
    if any(x in name for x in ["-coder", "starcoder", "codegen", "deepseek-coder"]):
        return "code"
    return "base"

# ── Provider display name mappings ────────────────────────────────────────────
PROVIDER_DISPLAY = {
    "meta-llama": ("Meta", "meta"),
    "mistralai": ("Mistral AI", "mistral"),
    "deepseek-ai": ("DeepSeek AI", "deepseek"),
    "openai": ("OpenAI", "openai"),
    "openai-community": ("OpenAI", "openai"),
    "microsoft": ("Microsoft", "microsoft"),
    "bigscience": ("BigScience", "bigscience"),
    "bigcode": ("BigCode", "bigcode"),
    "google": ("Google", "google"),
    "tiiuae": ("TII UAE", "tiiuae"),
    "xai-org": ("xAI", "xai"),
    "moonshotai": ("Moonshot AI", "moonshot"),
    "Qwen": ("Alibaba Qwen", "qwen"),
    "nvidia": ("NVIDIA", "nvidia"),
    "zai-org": ("Zhipu AI", "zhipu"),
    "HuggingFaceH4": ("Hugging Face", "huggingface"),
    "CohereLabs": ("Cohere", "cohere"),
    "TinyLlama": ("TinyLlama", "tinyllama"),
    "EleutherAI": ("EleutherAI", "eleutherai"),
    "MiniMaxAI": ("MiniMax AI", "minimax"),
    "01-ai": ("01.AI", "01ai"),
    "ai21labs": ("AI21 Labs", "ai21"),
    "openchat": ("OpenChat", "openchat"),
    "Nanbeige": ("Nanbeige", "nanbeige"),
    "01ai": ("01.AI", "01ai"),
}

CONTEXT_WINDOWS = {
    "llama-3.1": 131072, "llama-3.2": 131072, "llama-3.3": 131072,
    "deepseek-r1": 163840, "deepseek-v3": 163840,
    "phi-4": 16384, "phi-3-mini-128k": 131072,
    "gpt-2": 1024, "gpt-oss": 131072,
    "bloom": 2048, "falcon": 2048,
    "qwq-32b": 131072, "kimi-k2": 131072,
    "mixtral": 32768, "mistral-nemo": 131072, "mistral-large": 131072,
    "gemma-2": 8192, "gemma-3": 131072,
    "glm-4": 131072, "glm-5": 131072,
    "qwen2.5": 131072, "qwen3": 131072,
    "command-r": 131072,
}

ARCHITECTURE_MAP = {
    "mixtral": "MoE", "deepseek-v3": "MoE", "kimi-k2": "MoE",
    "jamba": "MoE", "minimax-m2": "MoE", "grok-1": "MoE",
    "qwen3-235": "MoE", "qwen3-coder-480": "MoE",
}

VISION_KEYWORDS = ["-vl", "-vision", "llava", "-mm", "multimodal"]


def slugify(text):
    text = text.lower()
    text = re.sub(r'[^a-z0-9]+', '-', text)
    return text.strip('-')[:80]


def fetch_hf_metadata(hf_id):
    url = f"https://huggingface.co/api/models/{hf_id}"
    req = urllib.request.Request(url, headers={"User-Agent": "ai-models-seed/1.0"})
    with urllib.request.urlopen(req, timeout=10) as r:
        return json.loads(r.read())


def transform(hf_id, hf_data):
    owner = hf_id.split("/")[0]
    model_name = hf_id.split("/")[-1]

    # License
    card_data = hf_data.get("cardData") or {}
    raw_license = card_data.get("license") or "unknown"
    license_clean = LICENSE_MAP.get(raw_license, raw_license)

    # Provider
    provider_display, provider_slug = PROVIDER_DISPLAY.get(
        owner, (owner, slugify(owner))
    )

    name = model_name.replace("_", "-")
    slug = slugify(name)

    # Family slug — derive from name
    family_slug = slug
    # Try to strip parameter suffix for family
    family_slug = re.sub(r'-\d+\.?\d*[bBmMkK]-?.*$', '', slug).strip('-') or slug

    variant = detect_variant(hf_id)

    is_vision = any(kw in hf_id.lower() for kw in VISION_KEYWORDS)
    modalities_input = ["text", "image"] if is_vision else ["text"]

    context_window = None
    for key, val in CONTEXT_WINDOWS.items():
        if key in family_slug or key in slug:
            context_window = val
            break

    architecture = "Transformer"
    for key, arch in ARCHITECTURE_MAP.items():
        if key in slug or key in family_slug:
            architecture = arch
            break

    likes = hf_data.get("likes", 0)
    is_featured = likes >= 2000

    release_date = (hf_data.get("createdAt") or "")[:10] or None

    # Parameter count — try to extract from name
    param_match = re.search(r'(\d+\.?\d*[bBmMkKtT])', model_name)
    parameter_count = param_match.group(1).upper() if param_match else None

    return {
        "hf_model_id": hf_id,
        "name": name,
        "slug": slug,
        "provider": provider_display,
        "provider_slug": provider_slug,
        "is_open_source": True,
        "license": license_clean,
        "family_slug": family_slug,
        "variant": variant,
        "parameter_count": parameter_count,
        "modalities_input": modalities_input,
        "modalities_output": ["text"],
        "is_active": True,
        "is_featured": is_featured,
        "source_url": f"https://huggingface.co/{hf_id}",
        "model_card_url": f"https://huggingface.co/{hf_id}",
        "context_window": context_window,
        "architecture": architecture,
        "release_date": release_date,
        "likes": likes,
        "short_description": "",  # agent fills this
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--ids", nargs="+", help="Specific HF model IDs to fetch")
    args = parser.parse_args()

    if args.ids:
        hf_ids = args.ids
    else:
        with open(INPUT_PATH) as f:
            candidates = json.load(f)
        hf_ids = [c["hf_model_id"] for c in candidates]

    if not hf_ids:
        print("No candidates to process.")
        with open(OUTPUT_PATH, 'w') as f:
            json.dump([], f)
        return

    print(f"🔍 Fetching HF metadata for {len(hf_ids)} models...")
    batch = []
    for hf_id in hf_ids:
        try:
            hf_data = fetch_hf_metadata(hf_id)
            record = transform(hf_id, hf_data)
            batch.append(record)
            print(f"  ✅ {hf_id} | variant={record['variant']} | license={record['license']}")
        except Exception as e:
            print(f"  ❌ {hf_id}: {e}")

    with open(OUTPUT_PATH, 'w') as f:
        json.dump(batch, f, indent=2, default=str)

    print(f"\n✅ Written {len(batch)} records to {OUTPUT_PATH}")
    print(f"   Agent: add short_description to each, save to /tmp/ai_models_enriched.json, then run aimodels_save.sh")


if __name__ == "__main__":
    main()
