---
name: skill-queue-refill
description: Refills the agent_skills discovery queue by searching GitHub for new SKILL.md files and queuing them as pending items. Use when running the hourly skill queue refill cron, or when the queue is low and more skills need to be discovered.
metadata: {"openclaw":{"requires":{"bins":["python3"],"env":["DATABASE_URL","GITHUB_TOKEN"]},"emoji":"🔄"}}
---

# Skill Queue Refill

Fills the `discovery_queue` with new `agent_skills` pending items by searching GitHub.

## Prerequisites

Install Python dependencies (one-time):

```bash
pip3 install -r {baseDir}/scripts/requirements.txt
```

## Run

```bash
python3 {baseDir}/scripts/search.py --quiet
```

**This script takes 60-90 seconds.** It searches GitHub API + queries the DB.

**Critical execution rules:**
1. Run with `exec` using `yieldMs: 90000` (90 seconds) so the command completes before polling
2. Do NOT poll the process log after 4 seconds
3. Do NOT kill and re-run the script
4. Do NOT check if the script is still running
5. Just wait - the JSON output will appear when it finishes
6. Progress messages go to stderr, the final JSON goes to stdout

Output is a single JSON line:

```json
{"pending_added": 5, "skipped": 12, "already_known": 8, "evaluated": 25}
```

## Options

- `--quiet` - Suppress verbose output; print only final summary JSON (use this for cron runs)
- `--dry-run` - Preview what would be queued without writing to DB
- `--max N` - Limit evaluation to N candidates (default: 50)

## Report

Reply with exactly one line:

```
Skill queue refill: +{pending_added} queued ({already_known} known, {skipped} skipped)
```

If `pending_added` is 0, that's fine - it means GitHub returned mostly known/low-quality repos this run. No action needed.
