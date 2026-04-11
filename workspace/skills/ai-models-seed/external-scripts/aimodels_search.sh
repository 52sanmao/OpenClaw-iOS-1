#!/usr/bin/env bash
# Search HuggingFace for new text-generation models not yet in DB
# Outputs /tmp/ai_models_candidates.json
python3 /home/openclaw/.openclaw/workspace/skills/ai-models-seed/scripts/search.py "$@"
