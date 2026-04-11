#!/bin/bash
# news_digest_save.sh — run news_digest_save.py with DB env
set -e
source /home/openclaw/.openclaw/workspace/site/.env.local 2>/dev/null || true
export DATABASE_URL
cd /home/openclaw/.openclaw/workspace/skills/news-digest/scripts
python3 news_digest_save.py "$@"
