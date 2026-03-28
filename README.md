# OpenClaw

A native iOS control room for the OpenClaw AI gateway. Monitor system health, run commands, manage cron jobs, inspect agent execution traces, track token usage, outreach metrics, and your blog pipeline — all from your phone.

Built with SwiftUI and Swift Concurrency. One dependency: [MarkdownUI](https://github.com/gonzalezreal/swift-markdown-ui) for rendering LLM markdown output.

## Screens

| Tab | Description |
|-----|-------------|
| **Home** | Dashboard with 6 cards: System Health (live-polling ring gauges), Commands (quick actions), Cron Jobs (last/next run), Token Usage (today/yesterday/7d with model breakdown), Outreach Stats (grid), Blog Pipeline (published + stages). Settings via toolbar gear. |
| **Crons** | Full job list with status badges, human-readable schedules, last/next run times, manual run button with confirmation. Tap → detail view → tap a run → agent execution trace. |
| **Pipelines** | Coming soon — live per-pipeline cards (Blog, Outreach, WhatsApp, Site Agent) |
| **Memory** | Browse workspace files (MEMORY.md, SOUL.md, daily logs, etc.) with markdown rendering. Add Figma-style comments on paragraphs, then submit to the AI agent to perform edits. Semantic search across all memory. |
| **Chat** | Coming soon — streaming conversations with your AI agent via SSE |

### Home Dashboard Cards

- **System Health** — CPU, RAM, Disk ring gauges with auto-polling every 15s (stops when not on Home tab). Uptime + load average.
- **Commands** — 6 quick action buttons (Doctor, Tail Logs, Security Audit, Backup, etc.) + "Show More" for 6 more. Each confirms before running, shows loading, then displays result in a modal with copy button.
- **Cron Summary** — Last run status + next upcoming run at a glance.
- **Token Usage** — Segmented control (Today/Yesterday/7 Days). Total tokens, cost, proportional bar (input/output/cache read/cache write), request counts (total/thinking/tool), collapsible per-model breakdown.
- **Outreach Stats** — 6-cell grid with leads, channels, conversions.
- **Blog Pipeline** — Published count, active pipeline stage pills, last published link.

### Cron Detail View

- **Header** — status badge, enable/disable toggle (with confirmation + auto-navigate back), "Run Now" button (with confirmation)
- **Schedule** — human-readable frequency, raw cron expression, timezone
- **Timing** — last run with status + error message, next run with absolute date, consecutive errors
- **Investigate with AI** — when a job has errors, a bold action button sends the error to the orchestrator agent. The agent checks logs, diagnoses root cause, and fixes the issue if possible. Shows live elapsed timer during investigation, then a structured report (Status/Root Cause/Action Taken/Impact) with copy button. Latest investigation saved locally per job — "Last investigated X ago" link to reopen without re-running.
- **Run History** — paginated (20 per page). Each entry: status, time, duration, model badge, total tokens, token breakdown bar (input/output/reasoning). Tap to expand markdown summary. Tap row to open trace.

### Agent Execution Trace

Full step-by-step trace of agent execution with metadata pills (model, provider, stop reason, tokens):
- **System Prompt** — initial instructions
- **Input Prompt** — the message that triggered the run
- **Thinking** — model reasoning (markdown)
- **Tool calls** — tool name + arguments
- **Tool results** — stdout/stderr output
- **Text responses** — final agent output (markdown)

### Memory Tab

- **File browser** — workspace files grouped by type (Context Files, Daily Logs, Reference)
- **Search** — semantic/full-text search across all memory files
- **File viewer** — markdown rendered paragraph by paragraph with MarkdownUI
- **Comment annotations** — tap any paragraph to add a comment (Figma-style). Comments show inline as orange cards.
- **Submit to agent** — review all comments, submit as a structured prompt to the AI agent via `/v1/chat/completions`. Agent performs the edits in its sandbox. View the response as markdown.

## Getting Started

1. Open `OpenClaw.xcodeproj` in Xcode
2. Build and run on a simulator or device (iOS 17+)
3. On first launch, paste your gateway Bearer token
4. The Home dashboard loads automatically — pull down to refresh

## API

All requests go to `https://api.appwebdev.co.uk` with `Authorization: Bearer <token>`.

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/stats/system` | CPU, RAM, disk, uptime, load |
| GET | `/stats/outreach` | Leads, emails, WhatsApp, conversions |
| GET | `/stats/blog` | Published count, pipeline stages |
| GET | `/stats/tokens?period=` | Token usage with model breakdown |
| POST | `/stats/exec` | Run predefined safe commands (allowlisted) |
| POST | `/tools/invoke` | Gateway tool calls (see below) |
| POST | `/v1/chat/completions` | Send prompts to agent (used for memory edits) |

### Tool Actions (via /tools/invoke)

| Tool | Action | Args | Purpose |
|------|--------|------|---------|
| `cron` | `list` | `includeDisabled: true` | List all cron jobs |
| `cron` | `runs` | `jobId`, `limit`, `offset` | Paginated run history |
| `cron` | `run` | `jobId` | Manual trigger |
| `cron` | `update` | `jobId`, `patch: {enabled}` | Toggle enabled/disabled |
| `gateway` | `restart` | — | Restart gateway process |
| `sessions_history` | — | `sessionKey`, `limit`, `includeTools` | Agent execution trace |
| `memory_get` | — | `path`, `sessionKey` | Read workspace file content |
| `memory_search` | — | `query`, `sessionKey` | Semantic/FTS search across memory |

### Stats Exec Commands (via /stats/exec)

Predefined server-side allowlist: `doctor`, `status`, `logs`, `security-audit`, `backup`, `channels-status`, `config-validate`, `memory-reindex`, `session-cleanup`, `plugin-update`.

### Gateway Config Required

- `tools.sessions.visibility = "all"` — allows reading cron run session traces
- `tools.profile = "full"` — enables sessions_history, sessions_list, memory_get, memory_search
- `memorySearch.extraPaths` — must include workspace root for accessing all `.md` files
- `gateway.http.endpoints.chatCompletions.enabled = true` — for agent-mediated memory edits

## Requirements

- iOS 17+
- Xcode 16+
- MarkdownUI via SPM

## License

Private — all rights reserved.
