#!/usr/bin/env bash
# Scrape paid provider pricing pages → /tmp/pricing_raw.json
python3 /home/openclaw/.openclaw/workspace/skills/ai-models-pricing/scripts/scrape.py "$@"
