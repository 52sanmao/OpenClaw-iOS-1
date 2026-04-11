---
name: mcp-app-discovery
description:
  Discovers and enriches MCP Apps (has_ui=true, ui:// resources) and MCP
  Servers (has_ui=false, tool/resource endpoints) from GitHub, saving to the
  mcpapp-store.com database. The agent does the writing; scripts handle all
  data fetching and DB writes. Each queue item has a mode field (apps|servers)
  that controls type and has_ui. See references/db-schema.md for schema.
---

# MCP Discovery — Enrichment

Covers both modes. Queue items carry `queue_mode: "apps"|"servers"` — drives `type` and `has_ui` in the DB automatically via save.py.

## Your workflow (3 steps)

### 1. Fetch raw data

```bash
bash /home/openclaw/mcp_fetch.sh
```

Outputs a JSON array with the next 2 pending repos. Each object includes `queue_mode` plus: `queue_id`, `owner`, `github_stars`, `github_description`, `pushed_at`, `npm_package`, `npm_meta`, `package_json`, `readme` (full), `file_tree`, `banner_url`, `screenshot_urls`, `icon_url`.

### 2. Write enriched content (you — no external API)

Add these fields to each JSON object. Fields marked *(both)* apply to all. Fields marked *(apps)* or *(servers)* are mode-specific.

**Required (both):**
- `name` — clean display name
- `slug` — URL-safe, lowercase-hyphens, max 80 chars
- `short_description` — max 160 chars, punchy, value-first. Don't start with "A ".
- `description` — structured markdown 200-400 words (see sections below)
- `install_command` — single universal one-liner for the copyable box
- `pricing` — `free`/`freemium`/`paid`/`subscription` (infer from README)
- `keywords` — 5-10 lowercase, domain-specific
- `source_url` — copy directly from the fetch JSON `source_url` field. **Never omit this — it's the dedup key.**
- `supported_hosts` — use slugs from this list (only include clients confirmed in README):
  `claude`, `vscode-copilot`, `cursor`, `goose`, `codex`, `gemini-cli`,
  `chatgpt`, `mcpjam`, `postman`, `librechat`, `zed`, `windsurf`
  **If no specific host is confirmed in the README, default to `["claude"]` — never leave this empty.**
- `category_slug` — one of: `data-visualization`, `forms-configuration`, `media-viewers`, `monitoring-dashboards`, `productivity`, `developer-tools`

**`description` sections — apps mode (queue_mode=apps):**
```
## What it does
Concrete use case — what interactive UI does it render?

## Key features
3-5 bullets. Specific UI capabilities and more, not generic fluff.

## Installation
Per-client with exact config snippets:
- Claude Desktop: JSON for claude_desktop_config.json
- VS Code Copilot: settings.json entry
- Claude.ai web: MCP server URL (if HTTP)

## Supported hosts
Only clients confirmed in README.
```

**`description` sections — servers mode (queue_mode=servers):**
```
## What it does
What system/service does it connect to? What can the AI do with it?

## Tools
List the key tools it exposes (name + one-line description each).
If README lists them, use those. Otherwise infer from code/description.

## Installation
Exact claude_desktop_config.json snippet.

## Supported hosts
Only clients confirmed in README.
```

**Servers-only fields:**
- `transport` — `stdio`/`http`/`sse` (infer from README)
- `tool_count` — integer if README lists tools, otherwise omit

**Metadata object (both):**
```json
{
  "mcpCapabilities": ["tools", "resources", "prompts"],
  "documentationUrl": "...",
  "demoUrl": "...",
  "installInstructions": {
    "claude-desktop": "JSON for claude_desktop_config.json",
    "claude-ai": "MCP server URL to add in Claude.ai Settings → Integrations",
    "vscode-copilot": "settings.json github.copilot.chat.mcp.servers entry",
    "cursor": "mcp.json entry in ~/.cursor/ or project .cursor/",
    "codex": "AGENTS.md or mcp config entry",
    "gemini-cli": "settings.json mcpServers entry",
    "goose": "goose configure entry",
    "chatgpt": "ChatGPT Connectors URL (requires HTTP transport + ngrok or hosted)",
    "zed": "settings.json context_servers entry",
    "windsurf": "mcp_config.json entry"
  }
  Only include hosts actually mentioned or confirmed in the README.
}
```

**Screenshots** — write as objects (both modes):
```json
[{ "url": "https://...", "alt_text": "what it shows", "caption": "one sentence" }]
```
For apps: hunt for YouTube thumbnails. For servers: skip if none found — servers rarely have screenshots.

### 3. Save

Write enriched JSON array to `/tmp/mcp_enriched.json`, then:

```bash
bash /home/openclaw/mcp_save.sh
```

`type` and `has_ui` are set automatically by save.py from `queue_mode` — do not set them yourself.

## Search scripts

```bash
bash /home/openclaw/mcp_search.sh              # apps mode (default)
bash /home/openclaw/mcp_search.sh --mode servers  # servers mode
```

Both populate the same `discovery_queue`. Fetch picks up whatever is pending regardless of mode.

## Reference

See `references/db-schema.md` for full field reference.
