//
//  AICodeChatMock.swift
//  Pi Dev
//

import Foundation

enum AICodeChatMock {
  static let chatTitles = [
    "Debounce repo search",
    "Add SwiftData sync",
    "Refactor networking layer",
    "Fix memory leak in image cache",
    "Design settings screen",
    "API error handling",
    "Implement push notifications",
    "Dark mode polish",
    "Unit tests for auth"
  ]

  static let models: [AgentModel] = [
    AgentModel(
      id: "claude-opus-4-6",
      name: "Opus 4.6",
      provider: "anthropic",
      contextWindow: 500_000,
      thinkingLevelMap: nil
    ),
    AgentModel(
      id: "claude-sonnet-4-6",
      name: "Sonnet 4.6",
      provider: "anthropic",
      contextWindow: 200_000,
      thinkingLevelMap: nil
    ),
    AgentModel(
      id: "claude-haiku-4-5",
      name: "Haiku 4.5",
      provider: "anthropic",
      contextWindow: 200_000,
      thinkingLevelMap: nil
    ),
  ]

  static let commands: [PiCommand] = [
    PiCommand(name: "commit", description: "Create a git commit", source: "extension", location: nil, path: "/pi/extensions/commit.ts"),
    PiCommand(name: "review", description: "Review code and suggest changes", source: "prompt", location: "project", path: "/pi/prompts/review.md"),
    PiCommand(name: "fix-tests", description: "Fix failing tests", source: "prompt", location: "project", path: "/pi/prompts/fix-tests.md"),
    PiCommand(name: "skill:brave-search", description: "Web search via Brave API", source: "skill", location: "user", path: "/pi/skills/brave-search/SKILL.md"),
    PiCommand(name: "skill:context7", description: "Fetch library docs", source: "skill", location: "user", path: "/pi/skills/context7/SKILL.md"),
    PiCommand(name: "session-name", description: "Set or clear session name", source: "extension", location: nil, path: "/pi/extensions/session.ts"),
  ]

  /// Fully populated sidebar + active chat for SwiftUI previews.
  static func seed(into sidebar: SidebarStore) {
    let iso = ISO8601DateFormatter()
    let now = Date()
    let yesterday = now.addingTimeInterval(-86_400)
    let lastWeek = now.addingTimeInterval(-86_400 * 5)

    sidebar.sessions = chatTitles.enumerated().map { index, title in
      let stamp: Date =
        index < 3 ? now
        : index < 6 ? yesterday
        : lastWeek
      let date = iso.string(from: stamp)
      return SessionInfo(
        path: "/mock/sessions/\(index)",
        id: "mock-session-\(index)",
        cwd: "/Users/dev/PiDevApp",
        name: title,
        created: date,
        modified: date,
        messageCount: index == 0 ? 2 : (index % 7) + 1,
        firstMessage: title,
        allMessagesText: title
      )
    }
    sidebar.selectedSessionId = sidebar.sessions.first?.id
    sidebar.searchText = ""
    seed(into: sidebar.activeChat)
  }

  static func seed(into store: ChatStore) {
    store.chatTitle = "Debounce repo search"
    store.availableModels = models
    store.availableCommands = commands
    store.selectedModel = models[1]
    store.thinkingLevel = .high
    store.supportedThinkingLevels = ThinkingLevel.defaultLevels
    store.messages = [
      ChatMessage(
        role: .user,
        text: "Search in the repo list fires an API call on every keystroke. Can you debounce it and add an offline fallback?",
        tokens: 210
      ),
      cannedReply(level: .high)
    ]
    store.usedTokens = 46_800
    store.draft = ""
    store.isResponding = false
    store.messageQueue = []
  }

  static func cannedReply(level: ThinkingLevel) -> ChatMessage {
    var reply = ChatMessage(
      role: .assistant,
      text: """
      Done — I added a debounced search to the repository list and wired up an offline fallback.

      The core change is in `SearchViewModel.swift`. Instead of calling `repo.search(query)` on every keystroke, the view model now publishes the query through a small `AsyncStream` pipeline. A 300 ms debounce window waits for the user to stop typing, and only the latest query is forwarded to the network layer. If a previous request is still in flight when the query changes, it gets cancelled automatically via the task idiom, so we never render stale results or waste bandwidth.

      For the offline path, I updated `RepositoryClient` to wrap network errors and fall back to `cachedSearch(_:)`. The cache is keyed by a normalized version of the query (lowercased and trimmed) so that "SwiftUI", "swiftui ", and "  swiftui  " all hit the same entry. When the device comes back online, the next fresh query invalidates the stale cache entry and re-fetches from the server.

      I also added two Swift Testing cases: one that simulates rapid keystrokes and asserts cancellation, and one that flips airplane mode on and verifies the cached payload is returned. Both pass locally.

      Next steps you might consider: adding a loading shimmer while debouncing, surfacing a small "offline — showing cached results" banner, and pre-warming the cache for the user's pinned repos. Want me to tackle any of those?
      """,
      code: (
        "swift",
        """
        @Observable
        final class SearchViewModel {
          var query = ""
          var results: [Repository] = []

          private let repo: RepositoryClient
          private var searchTask: Task<Void, Never>?

          init(repo: RepositoryClient) {
            self.repo = repo
          }

          func search() async {
            searchTask?.cancel()
            searchTask = Task {
              try? await Task.sleep(for: .milliseconds(300))
              guard !Task.isCancelled else { return }

              do {
                results = try await repo.search(query)
              } catch is URLError {
                results = await repo.cachedSearch(query)
              }
            }
          }
        }
        """
      ),
      tokens: 4_200
    )

    if level != .off {
      reply.thinking = Thinking(
        summary: "Weighed Combine debounce vs task(id:) vs AsyncStream — chose a small async pipeline for clarity and testability.",
        truncated: "The user wants search-as-you-type without hammering the API. Options: Combine's debounce, an AsyncStream, or task(id:) keyed on the query. Each gives cancellation, but a dedicated pipeline is easier to unit test and lets us inject a fake clock. Going with that.",
        full: """
        The user wants search-as-you-type without hammering the API.

        Options considered:
        1. Combine `debounce` on a published query — mature, but pulls Combine into an otherwise async/await codebase and needs manual cancellation of in-flight requests. It also makes deterministic unit testing harder because we have to manipulate scheduler time.
        2. `.task(id: query)` in the view — SwiftUI cancels the previous task whenever `id` changes, so sleeping 300 ms at the top gives debounce + cancellation in four lines. The downside is that logic lives in the view, which is harder to test and reuse.
        3. A lightweight `AsyncStream` pipeline inside the view model — exposes a plain `query` property and a `search()` method, debounces with `Task.sleep`, and cancels via a stored task reference. This is the easiest to test with a fake repository client and keeps UI logic out of the view.

        Going with option 3. Edge cases to handle:
        - Empty query should clear results immediately (skip the sleep).
        - Offline mode should serve the cached page — the repo layer already exposes `cachedSearch(_:)`, so I'll fall back there on URLError.
        - Normalize the cache key to avoid duplicate entries for "Swift " vs "swift".
        - Cancel the stored task in deinit to avoid leaks.

        Verified by running the existing SearchViewModelTests plus two new cases: rapid-typing cancellation and offline fallback. All green. I'll also add a small note in the PR about the new dependency on `RepositoryClient` error handling.
        """,
        seconds: 18.0
      )
    }

    reply.tools = [
      ToolUse(
        kind: .builtin,
        name: "bash",
        detail: "cd Mini-C-Compiler && git log -1 --format=\"%H%n%an%n%ae%n%ad%n%s\"",
        symbol: "terminal"
      ),
      ToolUse(kind: .builtin, name: "Search for .swift", detail: "Found SearchViewModel.swift, SearchView.swift, RepositoryClient.swift, SearchViewModelTests.swift", symbol: "magnifyingglass"),
      ToolUse(kind: .builtin, name: "Edit SearchViewModel.swift", detail: "+41 −4", symbol: "pencil.line"),
      ToolUse(kind: .builtin, name: "Edit RepositoryClient.swift", detail: "+28 −12", symbol: "pencil.line"),
      ToolUse(kind: .mcp, name: "Read SearchViewModel.swift", detail: "repository/SearchViewModel.swift", symbol: "arrow.triangle.branch"),
      ToolUse(kind: .skill, name: "swift-testing", detail: "Generated 4 test cases", symbol: "checkmark.seal")
    ]

    reply.terminal = [
      TerminalRun(
        command: "cd Mini-C-Compiler && git log -1 --format=\"%H%n%an%n%ae%n%ad%n%s\"",
        output: """
        a1b2c3d4e5f6789012345678901234567890abcd
        Alice Developer
        alice@example.com
        Mon Jul 7 14:22:11 2025 -0700
        Fix parser edge case for nested blocks
        """,
        exitCode: 0
      ),
      TerminalRun(
        command: "swift test --filter SearchViewModelTests",
        output: """
        Test Suite 'SearchViewModelTests' started
          ✔ debouncesRapidTyping (0.31s)
          ✔ fallsBackToCacheOffline (0.08s)
          ✘ cancelsInFlightOnNewQuery (0.12s)
            Issue recorded: Expected results.count == 1, but was 3
          ✔ clearsResultsOnEmptyQuery (0.04s)
          ✔ normalizesCacheKey (0.05s)
        Executed 5 tests, with 1 failure in 0.612 seconds
        """,
        exitCode: 1
      ),
      TerminalRun(
        command: "xcrun simctl boot \"iPhone 16\"",
        output: """
        An error was encountered processing the command (domain=NSPOSIXErrorDomain, code=60):
        Unable to boot device in current state: Booted
        """,
        exitCode: 60
      ),
      TerminalRun(
        command: "swift package resolve",
        output: """
        error: root manifest not found
        error: terminated(1): /usr/bin/xcrun --sdk macosx --find swift-package output:
         xcrun: error: unable to find utility "swift-package", not a developer tool or in PATH
        """,
        exitCode: 1
      ),
    ]

    return reply
  }
}
