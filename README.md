# Pi Dev

Mobile client for the **π coding agent** — chat with your codebase, run tools, and review diffs from your iPhone / iPad.

**Pi Dev Mobile is live on the App Store:**

**[→ Download Pi Dev Mobile on the App Store](https://apps.apple.com/app/pi-dev-mobile/id6789149807)**

> https://apps.apple.com/app/pi-dev-mobile/id6789149807

---

## Overview

Pi Dev is a native iOS app (SwiftUI + SQLiteData) that connects to a self-hosted π RPC server. Point it at your server URL, add your auth token, and you get a full streaming chat experience — assistant text, thinking blocks, tool calls, and terminal output — interleaved exactly as the agent produces them.

On first launch the app shows `SetupView` to configure `piServerBaseURL` and `piAuthToken` (stored via `@AppStorage` / `UserDefaults`). Once configured it streams via `PiRPCClient` (JSON-RPC over HTTP with SSE on `/events`) into `AICodeChatView`.

## Features

- **Streaming chat** — incremental text, thinking, tool use, and terminal runs rendered in order
- **Rich rendering** — Markdown, code blocks, pill labels, tool chips, and collapsible tool activity
- **Agent context** — context gauge, included repos, attached files, and pasted items
- **Queue & attachments** — queue messages while streaming, attach files, pick repos
- **Persistence** — local cache via [SQLiteData](https://github.com/pointfreeco/sqlite-data) (`appDatabase()`)

## Requirements

- Xcode 26.1+
- iOS 26.1+
- macOS 26.1+ (for Pi Dev Mac target)
- Swift 5.0

## Getting Started

```bash
git clone https://github.com/thisisommore/Pi-Dev-ios.git
open "Pi Dev.xcodeproj"
```

1. Select the **Pi Dev** scheme (auto-generated from targets; no shared `xcshareddata/xcschemes` committed) and a simulator / device.
2. Build and run (`Cmd+R`).
3. On first launch enter your **Pi Server URL** and **Auth Token** in the setup screen.

The client expects a π server that accepts `POST` RPC commands (e.g. `{ "type": "prompt", "message": "..." }`) and streams `response` events.

## Project Structure

```
.
├── Pi Dev/                 # iOS app — production target
│   ├── Pi_DevApp.swift     # @main — SetupView ↔ AICodeChatView
│   ├── Data/
│   │   ├── Database/       # SQLiteData setup (appDatabase)
│   │   ├── Model/          # ChatMessage, ToolUse, TerminalRun, etc.
│   │   ├── Network/        # PiRPCClient, PiRPCEvent (HTTP JSON-RPC + SSE)
│   │   └── Mock/           # Preview helpers (AICodeChatMock.swift)
│   └── UI/
│       ├── Pages/          # AICodeChat/ (5 files) + Setup/SetupView.swift
│       └── Views/          # MessageList, AssistantMessage, Composer, etc.
├── Pi Dev Mac/             # macOS target — mock UI only (see note below)
│   ├── Pi_Dev_MacApp.swift
│   ├── ContentView.swift
│   ├── Data/               # ChatStore.swift + MockData.swift
│   ├── Helpers/            # TitlebarAccessory.swift, WindowChrome.swift
│   ├── Models/ChatModels.swift
│   └── Views/              # SidebarView, ChatDetailView, ComposerView, etc.
├── Pi Dev.xcodeproj/       # Xcode project (6 targets: Pi Dev, Pi DevTests, Pi DevUITests, Pi Dev Mac, Pi Dev MacTests, Pi Dev MacUITests)
├── Pi DevTests/            # iOS unit tests
├── Pi DevUITests/          # iOS UI tests
├── Pi Dev MacTests/        # macOS tests (mock)
├── Pi Dev MacUITests/      # macOS UI tests (mock)
└── ci_scripts/             # Xcode Cloud helpers (ci_post_clone.sh, macros.json)
```

## Release

Pushing a `MARKETING_VERSION` bump in `Pi Dev.xcodeproj/project.pbxproj` to `main` triggers the `Release` GitHub Action (`.github/workflows/`), which creates an annotated tag `vX.Y.Z`. App Store submission remains manual.

---

## Note: Pi Dev Mac is mock only

The **Pi Dev Mac** target in this repository is a **UI mock / prototype only**. It does not connect to a real π server — all sessions, messages, and file diffs come from hard-coded data in [`Pi Dev Mac/Data/MockData.swift`](Pi%20Dev%20Mac/Data/MockData.swift) and `ChatStore`.

It exists to iterate on the desktop layout (sidebar, detail, changes sidebar, resize handles) and is **not shipped to the App Store**. The production app is **Pi Dev Mobile for iOS** — [available on the App Store](https://apps.apple.com/in/app/pi-dev-mobile/id6789149807).
