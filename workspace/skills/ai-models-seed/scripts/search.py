#!/usr/bin/env python3
"""
search.py — AI Models Seed
Fetches top text-generation models from HuggingFace API,
filters out quantized/community variants, dedupes against DB,
outputs up to 5 new candidates to /tmp/ai_models_candidates.json for agent judgment.

Run periodically (e.g. daily) to pick up newly trending models.
"""

import json, re, urllib.request, sys
from datetime import datetime, timezone

OUTPUT_PATH = "/tmp/ai_models_candidates.json"
MIN_LIKES = 500  # catches famous models under-liked on HF (many used via API, not starred)
HF_LIMIT = 150  # fetch top N from HF to ensure enough after filtering
BATCH_SIZE = 5

# Tags / name patterns that indicate quantized or derivative models to skip
SKIP_TAGS = {"gguf", "awq", "gptq", "bnb", "4bit", "quantized", "exl2", "mlx"}
SKIP_NAME_PATTERNS = [
    r"GGUF", r"AWQ", r"GPTQ", r"EXL2", r"-bnb-", r"-4bit", r"-8bit",
    r"unsloth/", r"-unsloth", r"TheBloke/",
]

# Known community fine-tunes to always skip
SKIP_HF_IDS = {
    "mattshumer/Reflection-Llama-3.1-70B",
    "dphn/dolphin-2.5-mixtral-8x7b",
    "HuggingFaceH4/zephyr-7b-alpha",  # alpha superseded by beta (already in DB)
    "Qwen/QwQ-32B-Preview",           # preview superseded by final (already in DB)
    "meta-llama/Llama-2-7b-hf",       # duplicate of Llama-2-7b (same weights)
    "meta-llama/Llama-2-13b-hf",      # base, instruct variant already in DB
    "meta-llama/Llama-2-70b-hf",      # base, instruct variant already in DB
}


def load_env():
    env = {}
    with open("/home/openclaw/.openclaw/workspace/site/.env.local") as f:
        for line in f:
            line = line.strip()
            if '=' in line and not line.startswith('#'):
                k, _, v = line.partition('=')
                env[k.strip()] = v.strip()
    return env


def get_saved_slugs(env):
    import psycopg2
    conn = psycopg2.connect(env['DATABASE_URL'])
    cur = conn.cursor()
    cur.execute("SELECT hf_model_id FROM ai_models WHERE hf_model_id IS NOT NULL")
    ids = {row[0] for row in cur.fetchall()}
    cur.execute("SELECT count(*) FROM ai_models")
    total = cur.fetchone()[0]
    conn.close()
    return ids, total


def fetch_hf_models(limit=HF_LIMIT):
    url = (
        f"https://huggingface.co/api/models"
        f"?pipeline_tag=text-generation&sort=likes&direction=-1&limit={limit}&full=false"
    )
    req = urllib.request.Request(url, headers={"User-Agent": "ai-models-seed/1.0"})
    with urllib.request.urlopen(req, timeout=15) as r:
        return json.loads(r.read())


def is_quantized(model):
    """Return True if model looks like a quantized/derivative variant."""
    mid = model.get("modelId", model.get("id", ""))
    tags = set(model.get("tags", []))
    # Tag check
    if tags & SKIP_TAGS:
        return True
    # Name pattern check
    for pat in SKIP_NAME_PATTERNS:
        if re.search(pat, mid):
            return True
    return False


def main():
    env = load_env()
    saved_hf_ids, total_in_db = get_saved_slugs(env)

    print(f"📊 DB currently has {total_in_db} models")
    print(f"🌐 Fetching top {HF_LIMIT} text-generation models from HuggingFace...")

    hf_models = fetch_hf_models()
    print(f"   Got {len(hf_models)} results from HF API")

    candidates = []
    seen_below_threshold = 0

    for m in hf_models:
        mid = m.get("modelId", m.get("id", ""))
        likes = m.get("likes", 0)

        if likes < MIN_LIKES:
            seen_below_threshold += 1
            continue

        if mid in SKIP_HF_IDS:
            continue

        if is_quantized(m):
            continue

        if mid in saved_hf_ids:
            continue  # already in DB

        # New candidate
        candidates.append({
            "hf_model_id": mid,
            "name": mid.split("/")[-1],
            "provider_hf": mid.split("/")[0],
            "likes": likes,
            "tags": m.get("tags", []),
            "pipeline_tag": m.get("pipelineTag", "text-generation"),
            "created_at": (m.get("createdAt") or "")[:10],
        })

    print(f"   {len(candidates)} new candidates above {MIN_LIKES} likes (not yet in DB)")

    batch = candidates[:BATCH_SIZE]

    if not batch:
        print("✅ No new models to add — DB is up to date.")
        with open(OUTPUT_PATH, 'w') as f:
            json.dump([], f)
        return

    print(f"\n📦 Returning {len(batch)} candidates for agent judgment:")
    for c in batch:
        print(f"   • {c['hf_model_id']} | likes={c['likes']} | created={c['created_at']}")

    with open(OUTPUT_PATH, 'w') as f:
        json.dump(batch, f, indent=2)

    print(f"\n✅ Written to {OUTPUT_PATH}")
    print(f"   Agent: judge each candidate, enrich approved ones, save to /tmp/ai_models_enriched.json, then run aimodels_save.sh")


if __name__ == "__main__":
    main()
