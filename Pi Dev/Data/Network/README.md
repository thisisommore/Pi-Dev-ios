# PiRPC

`PiRPCClient` is the concrete implementation used by the app to talk to a π coding-agent server.
It owns auth, JSON-RPC `POST /rpc`, session REST (`GET /sessions`), SSE on `/events`, the polling fallback, and cancel/abort.

# PiRPCP for mocks

`PiRPCP` is the shared protocol that the app uses instead of depending directly on `PiRPCClient`.
`ChatStore` and `SidebarStore` take `any PiRPCP`, so the real implementation (`PiRPCClient`) and a mock stay aligned.
This makes previews and test-style flows work without changing app code or touching the real network.

# Setup

The client reads `piServerBaseURL` and `piAuthToken` from `UserDefaults` (set on the Setup page). Bare hostnames are normalized to `https://`.

### First launch

For a new install (empty URL or token), `Root` shows `SetupPage`. After a successful `healthCheck` (`get_state`), URL and token are stored and chat opens.

### Returning user

For a configured user, `Root` shows `AICodeChatView`. `SidebarStore` hydrates from `PiCache`, then revalidates:

- `listSessions` (`GET /sessions`)
- `get_available_models` / `get_commands`
- `switch_session` + `get_entries` for the open chat

### Logout

`SidebarStore.logout()`:

- clears in-memory sessions and the active `ChatStore`
- calls `PiCache.clearAll()`
- does not clear `piServerBaseURL` / `piAuthToken` (those stay until the user changes them on Setup)

# Chat turn

Typical prompt flow:

- `set_thinking_level`
- `prompt` or `rerun`
- SSE `GET /events` until `agent_end` (or poll `get_last_assistant_text` / `get_messages` if SSE is unavailable)
- `abort` to stop generation

New-chat drafts create the server session lazily via `new_session` inside the first prompt, so Send cannot race `newChat`.

# Callbacks

Streaming is an `AsyncStream<AgentEvent>`. Event parsing lives in `PiRPCEvent.swift`.
The stream bridge lives in `PiRPCClient+Stream.swift`.

# Dependencies

Main dependencies used in this folder:

- `Foundation` for URLSession, JSON, files, and SSE byte streams
- `PiRPCP` for the mockable surface used by stores

# Files

- `PiRPC+Protocols.swift` — `PiRPCP`
- `PiRPCClient.swift` — auth, typed RPC commands, `send`, `cancel`; conforms via `extension PiRPCClient: PiRPCP`
- `PiRPCClient+Stream.swift` — SSE + poll
- `PiRPCClient+Models.swift` — `SessionInfo`, RPC response wrappers
- `PiRPCEvent.swift` — `AgentEvent` and JSON mapping
