# Data

Persistent state, cache, models, and the π RPC client live here.

# Database

`Database.swift` creates the SQLiteData store and runs migrations in order (`v1()`, `v2()`, `v3()`, …).

`PiCache` reads and writes cached sessions, models, commands, and chat snapshots so the UI can paint before the network returns.

`CacheSchema.swift` defines the SQLiteData table types.

# Migrations

New schema changes go in `Migration/`. Raw SQL is preferred. Each file extends `DatabaseMigrator` and is called from `appDatabase()` in `Database.swift`.

# Models

`Model/` holds UI and cache types such as `ChatMessage`, `ToolUse`, `TerminalRun`, and `PiCommand`.

# Network

See `Network/README.md`. Depend on `PiRPCP`, not `PiRPCClient`, so previews can swap a mock.

# Mock

`Mock/AICodeChatMock.swift` seeds `SidebarStore` for SwiftUI Previews (`SidebarStore.preview`).
