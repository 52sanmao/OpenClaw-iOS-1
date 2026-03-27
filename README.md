# OpenClaw

A native iOS control room for the OpenClaw AI gateway. Monitor system health, manage cron jobs, track outreach metrics, and oversee your blog pipeline — all from your phone.

Built with SwiftUI and Swift Concurrency. Zero third-party dependencies.

## Screens

| Tab | Description |
|-----|-------------|
| **Home** | Dashboard with 4 summary cards: System Health (ring gauges), Cron Jobs (last/next run), Outreach Stats (grid), Blog Pipeline (published count + stages). Settings via toolbar gear. |
| **Crons** | Full job list with status badges, human-readable schedules, last/next run times, manual run button. Tap for detail view. |
| **Pipelines** | Coming soon — live per-pipeline cards (Blog, Outreach, WhatsApp, Site Agent) |
| **Memory** | Coming soon — browse and edit workspace files (MEMORY.md, daily notes, skills) |
| **Chat** | Coming soon — streaming conversations with your AI agent via SSE |

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
| POST | `/tools/invoke` | Tool calls (cron list, exec, future: read/write files) |

## Requirements

- iOS 17+
- Xcode 16+
- No external dependencies

## License

Private — all rights reserved.
