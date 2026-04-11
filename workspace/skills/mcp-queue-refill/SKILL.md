---
name: mcp-queue-refill
description: Refills the MCP app/server discovery queue by searching GitHub for new MCP repos and queuing them as pending items. Runs separately for apps (mode=apps) and servers (mode=servers). Use when running the MCP queue refill cron, or when the apps/servers queue is low.
---

# MCP Queue Refill

Fills the `discovery_queue` with new `apps` pending items by searching GitHub.

## Run

Two separate scripts — one per mode:

**Apps:**
```bash
bash /home/openclaw/mcp_search.sh
```

**Servers:**
```bash
bash /home/openclaw/mcp_search_servers.sh
```

Each outputs a single JSON line:

```json
{"mode": "apps", "pending_added": 8, "skipped": 10, "already_known": 22, "evaluated": 40}
```

## Report

One line per script run:

```
MCP {mode} queue refill: +{pending_added} queued ({already_known} known, {skipped} skipped)
```

If `pending_added` is 0, that's normal — queue may already be saturated or GitHub returned only known repos.
