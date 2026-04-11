#!/usr/bin/env bash
# Fetch full HF metadata + apply transforms for candidates in /tmp/ai_models_candidates.json
# Outputs /tmp/ai_models_batch.json ready for agent enrichment (short_description only)
# Usage: bash aimodels_fetch.sh
#        bash aimodels_fetch.sh --ids owner/model1 owner/model2
python3 /home/openclaw/.openclaw/workspace/skills/ai-models-seed/scripts/fetch.py "$@"
