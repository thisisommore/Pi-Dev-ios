# Pi Dev

Native iOS client for the **π coding agent**. Chat with your codebase, run tools, and review diffs from iPhone / iPad.

**[Download Pi Dev Mobile on the App Store](https://apps.apple.com/app/pi-dev-mobile/id6789149807)**

> **Note:** First launch opens setup. Enter your π server URL and auth token. After that, the app streams chat over JSON-RPC + SSE.

## Setup

Follow these steps to get the app running locally with the iOS Simulator.

### Prerequisites

- **Xcode:** Developed with Xcode 26. The current latest version should work.
- A running [π RPC server](https://github.com/thisisommore/pi-backend) (URL + token)

### Open project

Open the project in Xcode:

```bash
open "Pi Dev.xcodeproj"
```

Select the **Pi Dev** scheme and a simulator / device.

This project uses SPM (Swift Package Manager) and it should fetch dependencies automatically.

You can run build or run in simulator to test the application.

On first launch, enter **Server URL** and **Auth Token**.

## Dependencies

This project relies on the following Swift packages (managed via SPM):

- **SQLiteData:** Based on GRDB, used for robust and type-safe SQLite database management (session cache, models, chat snapshots).
https://github.com/pointfreeco/sqlite-data

`swift-dependencies` is pulled in by SQLiteData and is used at launch (`prepareDependencies`) and in previews.

## Contributing

### Formatting

We use [SwiftFormat](https://github.com/nicklockwood/SwiftFormat) to format our Swift files.

```bash
# Install
brew install swiftformat

# Run
swiftformat .
```

### Linting

We use [SwiftLint](https://github.com/realm/SwiftLint) to lint our Swift files.

```bash
# Install
brew install swiftlint

# Run
swiftlint .
```

## Architecture

### View Controller Pattern

Most of the app relies on a view controller pattern. Logic and state management live in a controller (`+Controller.swift`), which SwiftUI view should initialize and call as needed.

Examples:

- `Setup.page.swift` → `Setup+Controller.swift`
- `AICodeChat.page.swift` → `AICodeChat.page+Controller.swift` (`ChatStore`) and `Sidebar+Controller.swift`
- Chat list UIKit: `ChatMessages+Controller.swift` (`ChatMessagesVC`)

### Main.swift & Entrypoint

Everything starts with `Main.swift`. It acts as a container for `Provider` and `Root` and should be kept as clean as possible (< 30 lines).

- **Provider:** Initializes shared environment (label color, future global objects).
- **Root:** Handles all initial logic, including routing new vs returning users (setup vs chat) from stored server URL and auth token.

### Data

All persistent data-related code lives in the `Data` folder. This includes:

- Database logic powered by `SQLiteData` (`Database.swift`, `PiCache`).
- Key-value storage using `UserDefaults` (`piServerBaseURL`, `piAuthToken`).
- Network client in `Data/Network` (`PiRPCClient`).
- Models in `Data/Model`.
- Preview seeds in `Data/Mock`.

See `Pi Dev/Data/README.md`.

##### Migrations

New database changes go in `Data/Migration`. Raw SQL is preferred because it is easy to read and avoids assumptions an ORM might make. Migrations should extend `DatabaseMigrator`.

```swift
extension DatabaseMigrator {
  mutating func v2() {
    self.registerMigration("v2:hello") { db in
      try #sql(
        """
        CREATE TABLE "hello"(
          "id" TEXT NOT NULL PRIMARY KEY
        ) STRICT
        """
      )
      .execute(db)
    }
  }
}
```

Migrations should then be called sequentially in `Database.swift`:

```swift
migrator.v1()
migrator.v2()
migrator.v3()
// ...
try migrator.migrate(database)
```

### UI & Navigation

- **Navigation:** We use a `Destination` enum to define navigation destinations. See `Navigation.swift` for details. `Root` switches setup vs chat through `Destination`. The chat page uses a custom sidebar overlay (not a `NavigationStack` push) so the transcript stays on screen.

    ```swift
    enum Destination: Hashable {
        case setup
        case chat
    }

    extension Destination {
        @MainActor @ViewBuilder
        func _destinationView() -> some View {
            switch self {
            case .setup:
                SetupPage()
            case .chat:
                AICodeChatView()
            }
        }
    }
    ```

- **Pages:** All screens and pages live in the `UI/Pages` folder. The entry point for a page is defined by `*.page.swift`.
    - `Setup/Setup.page.swift`
    - `AICodeChat/AICodeChat.page.swift` (sidebar + detail)
    - Previews are heavily utilized to build UI quickly without waiting for full builds to complete.
    - `PreviewUtils` contains `Mock` and helpers that can be attached to any preview to quickly set up the necessary data and environment.

- **Chat list:** UIKit collection view lives in `UI/Pages/AICodeChat/ChatMessagesCV/`, split with the `+XYZ` pattern (`+Controller`, `+Representable`, `+CVLayout`, `+CVDelegate`, `+Cell`, `+Chrome`, `+Type`).

- **Views:** Shared SwiftUI pieces live in `UI/Views` (Composer, Header, AssistantMessage, …).

### PiRPC

All π server-related code (client, events, protocol, documentation) lives in `Data/Network`.

- **Best practice:** When talking to the server, always use the `PiRPCP` protocol. This ensures that mocks can be provided in place without requiring major code changes, which is especially useful in SwiftUI Previews.

See `Pi Dev/Data/Network/README.md`.

## Code Style

### Naming Conventions

#### Controllers

Controllers follow the `+Controller` suffix pattern. They manage state and logic for SwiftUI views.

```swift
@Observable
class ChatStore {
  var messages: [ChatMessage] = []
}
```

#### Extensions

Use extensions to separate groups of related code:

```swift
class A { /* props, init */ }
extension A { /* methodA, methodB */ }
```

When implementing protocols, try to use extension and keep one
extension per protocol implementation. \
Don't try to implement multiple protocol in one group.

```swift
class A {  }
extension A: ProtocolXYZ
extension A: ProtocolABC
```

### UIKit
In UIKit define and use makeUI instead of using init
Try to keep init as clean as possible

#### +ABC.swift

In Swift, scope is shared across files, so identical file names in different folders collide. Use the `+XYZ` prefix pattern to avoid this.

#### Protocols

Use protocols to support mocking and previews — they allow you to replace a real implementation with a mock. Also use protocols to define common types and methods. For example, we use `PiRPCP` so stores do not depend on `PiRPCClient` directly.

### Formatting

#### Line Length

Try to keep files under 500 lines.

#### Linting & Formatting

Lint and formatting configs are provided. Use them to maintain the codebase and catch bugs early.

#### SwiftUI View Property Ordering

For SwiftUI views, follow this strict property ordering:

1. Controller state
2. Normal vars (non-state, props, `@Binding`)
3. Environment variables
4. `@Dependency`
5. Fetch hooks
6. `@State` / `@FocusState`
7. Anything else (helper methods, constants)
8. `body` (always last)

**Example:**

```swift
struct ExampleView: View {
  // 1. Controller state
  @State private var controller = ExampleController()

  // 2. Normal vars / props / @Binding
  let title: String
  @Binding var isPresented: Bool

  // 3. Environment variables
  @Environment(\.dismiss) private var dismiss

  // 4. Dependencies
  @Dependency(\.defaultDatabase) private var database

  // 5. Fetch hooks
  @FetchAll(Item.order { $0.name }) private var items: [Item]
  @FetchOne private var selectedItem: Item?

  // 6. States
  @State private var searchText = ""
  @FocusState private var isSearchFocused: Bool

  // 7. Anything else
  private var pageSize = 20

  // 8. Body
  var body: some View {
    Text(title)
  }
}
```

in each class, all properties non function with init and overrides, then all functions private with private extension then all public functions.
each protocol delegate should be simplified
Like
class A {}
extension A: Max {}
extension A: Tax {}
Wrong
class A: Max, Tax {}

See `ChatMessages+Controller.swift` and `ChatMessages+CVDelegate.swift` for example.

## Note: Pi Dev Mac is mock only

The **Pi Dev Mac** target is a UI mock / prototype. It does not connect to a π server. It is **not shipped**. Production is **Pi Dev Mobile for iOS**.
