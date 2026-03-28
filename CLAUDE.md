# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

- Never build automatically — user runs manually via Xcode.
- **Project**: `OpenClaw.xcodeproj` (no workspace)
- **Dependencies**: MarkdownUI via SPM (`https://github.com/gonzalezreal/swift-markdown-ui`)
- **Bundle ID**: `co.uk.appwebdev.OpenClaw`
- **Deployment**: iOS 17+, Swift 6 patterns (`@Observable`, strict `Sendable`)

## Architecture

Clean Architecture with MVVM per feature, protocol-based DI, and a generic ViewModel base.

### Layer flow

```
View → LoadableViewModel<T> → Repository protocol → GatewayClientProtocol → URLSession
                                      ↓
                                 MemoryCache (actor, TTL)
```

### Key abstractions

- **`LoadableViewModel<T>`** (`Core/LoadableViewModel.swift`): `@Observable @MainActor` base. Handles `data`, `isLoading`, `error`, `isStale`, `start()`, `refresh()`, `cancel()`. Feature VMs are one-liner subclasses.

- **`GatewayClientProtocol`** (`Core/GatewayClient.swift`): Four methods: `stats()` (GET, `.convertFromSnakeCase`), `statsPost()` (POST to `/stats/*`, `.convertFromSnakeCase`), `invoke()` (POST to `/tools/invoke`, camelCase — no conversion), `chatCompletion()` (POST to `/v1/chat/completions` with session key header, 15min timeout).

- **Repository protocols** (`Core/Repositories/`): One per feature. `Remote*Repository` owns a `MemoryCache<T>` actor and maps DTO→domain.

- **DTOs vs Domain models**: `Decodable` types in `Core/Networking/DTOs/` (suffixed `DTO`). Domain models in feature folders with `init(dto:)` mappers. Domain types use `Date`, `URL?` etc.

### Navigation

`ContentView` (auth gate) → `MainTabView` (5 tabs): Home, Crons, Pipelines (placeholder), Memory, Chat (placeholder). Settings via Home toolbar gear.

Shared state: `CronSummaryViewModel`, `CronDetailRepository`, and `GatewayClient` created once in `MainTabView`, shared across tabs.

Depth: Crons tab → `CronDetailView` → tap run → `SessionTraceView`. Memory tab → `MemoryFileView` → `SubmitEditsSheet`.

### Design system

All views use semantic tokens — never raw literals:
- `Spacing` — 4pt grid (xxs=4 through xxl=48)
- `AppColors` — `.success`, `.danger`, `.metricPrimary`, `.gauge(percent:warn:critical:)`
- `AppTypography` — `.heroNumber`, `.cardTitle`, `.actionIcon`, `.badgeIcon`, `.statusIcon`, `.nano`
- `AppRadius` — `.sm`(8), `.md`(10), `.lg`(12), `.card`(16)
- `Formatters` — cached date formatters, `Formatters.tokens()` for token counts, `Formatters.copyToClipboard()` for clipboard with haptic + reset timer

Sub-grid visual details (2pt padding, 6pt dots, 8pt indicator circles) are acceptable as raw values.

### Shared components

- `CronStatusDot` / `CronStatusBadge` — reused across cron list, detail, and trace. Badge supports `.small` and `.large` styles.
- `TokenBreakdownBar` — proportional bar + legend (input/output/reasoning split).
- `CardContainer`, `CardLoadingView`, `CardErrorView` — dashboard card shells.
- `CommandButton` — reusable quick action button with icon, label, loading state.
- `ElapsedTimer` — live-updating elapsed time counter for long-running agent calls.

### Local storage

- `InvestigationStore` (`Core/Storage/InvestigationStore.swift`): `InvestigationStoring` protocol + UserDefaults implementation. Stores latest `SavedInvestigation` per cron job ID. Used to show "Last investigated X ago" link in cron detail.

## Conventions

- **New features**: DTO in `Core/Networking/DTOs/`, domain model in feature folder with `init(dto:)`, repository protocol + `Remote*` in `Core/Repositories/`, VM subclass of `LoadableViewModel<T>`, view using `CardContainer` for dashboard cards.
- **Concurrency**: `@MainActor` on all ViewModels. `@Sendable` closures for loaders. Actor-based `MemoryCache`. No `@unchecked Sendable`.
- **Logging**: `os.Logger` (subsystem: `co.uk.appwebdev.openclaw`), never `print()`.
- **Accessibility**: All custom visual components need `.accessibilityElement` + `.accessibilityLabel`.
- **Haptics**: `Haptics.shared` for user action feedback (refresh, save, errors).
- **UI**: Design tokens only. Skeleton shimmer via `.shimmer()`. `CardLoadingView`/`CardErrorView` for card states.
- **File size**: Keep files under 300 lines. Extract into separate files when growing.
- **Pagination**: Limit/offset with "Load More" button. Deduplicate on append by ID. See `CronDetailViewModel`.
- **Formatters**: `Formatters.relativeString(for:)` / `Formatters.absoluteString(for:)` for dates. `Formatters.tokens()` for token counts. `Formatters.copyToClipboard()` for clipboard. Never duplicate these utilities — single source in `Formatters.swift`.
- **Markdown**: `Markdown(text).markdownTheme(.openClaw)` for LLM content. Never `AttributedString(markdown:)`. MarkdownUI v2 has no `.table` theme API.
- **Terminal output**: Strip ANSI codes with `CommandsViewModel.stripAnsi()`. Display in monospace (`AppTypography.captionMono`) with tinted background.
- **Confirmations**: Destructive actions (run cron, disable job, run command) must show an alert with confirmation before executing.
- **Prompt templates**: All agent prompts live in `Core/Prompts/PromptTemplates.swift` — one file, easy to tune.
- **Memory annotation pattern**: Files are read-only in the UI. Users add comments on paragraphs, then submit as a batch to the agent. Never write files directly — always agent-mediated.
- **Long-running agent calls**: Use `ElapsedTimer` to show live elapsed time. Never set short timeouts on `chatCompletion()` — agent may take 15+ minutes for complex tasks (investigations, file edits).
- **Investigation persistence**: Save latest investigation per job to `InvestigationStore`. Show "Last investigated X ago" link to reopen previous result without re-running.

## Prompt Engineering

All prompts sent to the agent follow these principles:

- **Never send full file content** — the agent has the file on disk. Send the path, line numbers, and a few lines of context (±2 lines around the target). The agent reads the file itself with the `read` tool.
- **Tell the agent what tools to use** — explicitly say "use the read tool", "use the write tool".
- **Give the workspace root path** — `~/.openclaw/workspace/orchestrator/`.
- **Session key matters** — `/v1/chat/completions` without `x-openclaw-session-key` header starts a blank isolated session with NO workspace access. Must use `chatCompletion()` method with `sessionKey: "agent:orchestrator:main"`.
- **Structure: task → steps → rules** — system prompt says what the task is, numbered steps to follow, then rules/constraints. User message has only the data.
- **Context padding** — include 2 lines before and after the target section in a code block.
- **Agent should act, not just report** — for investigations, the prompt tells the agent to fix the issue in the same call if possible, then report what it did. Don't just suggest next steps.

## Gateway API Gotchas

- **Four client methods**: `stats()` (GET, snake_case decoder), `statsPost()` (POST `/stats/*`, snake_case decoder), `invoke()` (POST `/tools/invoke`, camelCase, no conversion), `chatCompletion()` (POST `/v1/chat/completions`, session key header, 15min timeout via dedicated `URLSession`).
- **URL construction**: `stats()` and `statsPost()` build URLs via string interpolation, not `.appending(path:)` — the latter percent-encodes `?` breaking query strings.
- **Shell commands**: `exec` tool blocked over HTTP (needs agent sandbox). Use `POST /stats/exec` with allowlisted command key.
- **Cron list**: Pass `includeDisabled: true` to get all jobs including disabled ones.
- **Cron schedules**: `kind: "cron"` has `expr`, `kind: "every"` has `everyMs` (no `expr`). DTO `expr` must be optional.
- **Session history**: Tool is `sessions_history` (not `sessions`). Takes `sessionKey` (full format), not `sessionId` (bare UUID).
- **Error responses**: Gateway in-envelope errors (200 OK with `{"status":"error"}`) surface as decode failures. Handle gracefully in VMs.
- **System health polling**: `SystemHealthViewModel` has its own 15s polling loop — starts on `onAppear`, stops on `onDisappear`.
- **Memory tools**: `memory_get` and `memory_search` require `sessionKey: "agent:orchestrator:main"`. Config must have `memorySearch.extraPaths` for non-memory root files.
- **Chat completions timeout**: Uses dedicated `longRunningSession` (15min timeout) — agents may take minutes for investigations or file edits. Never use `URLSession.shared` for this endpoint. `ChatCompletionResponse` includes `usage` (prompt_tokens, completion_tokens, total_tokens) and `model`.
