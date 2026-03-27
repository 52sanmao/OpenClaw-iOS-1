# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

- Never build automatically — user runs manually via Xcode.
- **Project**: `OpenClaw.xcodeproj` (no workspace, no SPM, no CocoaPods)
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

- **`LoadableViewModel<T>`** (`Core/LoadableViewModel.swift`): `@Observable @MainActor` base class. All feature VMs are one-liner subclasses passing a loader closure. Handles `data`, `isLoading`, `error`, `isStale`, `start()`, `refresh()`, `cancel()` with structured Task management.

- **`GatewayClientProtocol`** (`Core/GatewayClient.swift`): `stats()` (GET) and `invoke()` (POST with wrapped response envelope). Concrete `GatewayClient` is a `Sendable` struct.

- **Repository protocols** (`Core/Repositories/`): One per feature. `Remote*Repository` owns a `MemoryCache<T>` actor and maps DTO→domain.

- **DTOs vs Domain models**: `Decodable` types in `Core/Networking/DTOs/` (suffixed `DTO`). Domain models in feature folders with `init(dto:)` mappers using richer types (`Date`, `URL?`).

### Navigation

`ContentView` (auth gate) → `MainTabView` (5 tabs): Home, Crons, Pipelines (placeholder), Memory (placeholder), Chat (placeholder). Settings accessed via Home toolbar gear icon.

`CronSummaryViewModel` is shared between the Home cron card and Crons tab — created once in `MainTabView`.

### Design system

All views use semantic tokens — never raw literals:
- `Spacing` — 4pt grid (xxs=4 through xxl=48)
- `AppColors` — `.success`, `.danger`, `.metricPrimary`, `.gauge(percent:warn:critical:)`
- `AppTypography` — Dynamic Type styles (`.heroNumber`, `.cardTitle`, `.metricValue`)
- `AppRadius` — `.sm`(8), `.md`(10), `.lg`(12), `.card`(16)

## Conventions

- **New features**: DTO in `Core/Networking/DTOs/`, domain model in feature folder with `init(dto:)`, repository protocol + `Remote*` in `Core/Repositories/`, VM subclass of `LoadableViewModel<T>`, view using `CardContainer` for dashboard cards.
- **Concurrency**: `@MainActor` on all ViewModels. `@Sendable` closures for loaders. Actor-based `MemoryCache`. No `@unchecked Sendable`.
- **Logging**: `os.Logger` (subsystem: `co.uk.appwebdev.openclaw`), never `print()`.
- **Accessibility**: All custom visual components need `.accessibilityElement` + `.accessibilityLabel`.
- **Haptics**: `Haptics.shared` for user action feedback (refresh, save, errors).
- **UI**: Use design tokens exclusively. Skeleton shimmer for loading states via `.shimmer()`. `CardLoadingView`/`CardErrorView` for card states.
