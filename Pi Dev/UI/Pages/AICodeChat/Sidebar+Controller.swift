//
//  Sidebar+Controller.swift
//  Pi Dev
//

import Observation
import SwiftUI
import Combine

@MainActor
@Observable
final class SidebarStore {
  var sessions: [SessionInfo] = []
  var selectedSessionId: String? = nil
  var activeChat: ChatStore
  var searchText = ""
  /// True while a background network revalidation is in flight.
  var isRefreshing = false

  @ObservationIgnored
  let rpcClient: any PiRPCP

  /// - Parameter connectToServer: When `false`, skip RPC bootstrap (previews / offline mocks).
  init(connectToServer: Bool = true, rpcClient: any PiRPCP = PiRPCClient()) {
    self.rpcClient = rpcClient
    activeChat = ChatStore(connectToServer: connectToServer, rpcClient: rpcClient)
    activeChat.onNewSessionAdopted = { [weak self] newId in
      Task { @MainActor in
        await self?.adoptNewChatSession(newId)
      }
    }
    activeChat.onStreamCompleted = { [weak self] in
      await self?.refreshSessionsAfterPrompt()
    }
    activeChat.onFirstTokenForNewChat = { [weak self] in
      await self?.handleFirstTokenForNewChat()
    }
    activeChat.createServerSessionForDraft = { [weak self] in
      await self?.createServerSessionForDraft()
    }
    guard connectToServer else { return }
    hydrateFromCache()
    Task { @MainActor in
      await refreshFromServer()
    }
  }

  /// Creates a new server session for a draft new-chat. This is the ONLY
  /// place that issues `new_session` for a draft, so the Send action cannot
  /// race with a concurrent newChat task. Inserts an optimistic placeholder
  /// so the sidebar shows instantly (before first token), then refreshes via
  /// RPC to reconcile with the server's real listing.
  func createServerSessionForDraft() async -> String? {
    // Capture the draft title before we mutate state.
    let placeholderTitle = activeChat.chatTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    let titleForPlaceholder = placeholderTitle.isEmpty || placeholderTitle == "New chat"
      ? (activeChat.messages.first?.text.prefix(34).description ?? "New chat")
      : placeholderTitle
    do {
      _ = try await rpcClient.newSession()
      let state = try await rpcClient.getState()
      guard let newId = state.data?.sessionId, !newId.isEmpty,
            let path = state.data?.sessionFile, !path.isEmpty else { return nil }
      // Optimistic placeholder — appears instantly in sidebar, even before
      // the server's session file is listed via GET /sessions.
      let now = ISO8601DateFormatter().string(from: Date())
      let placeholder = SessionInfo(
        path: path,
        id: newId,
        cwd: "",
        name: nil,
        created: now,
        modified: now,
        messageCount: 1,
        firstMessage: titleForPlaceholder,
        allMessagesText: titleForPlaceholder
      )
      await MainActor.run {
        // Insert at top; deduplicate if a previous placeholder exists.
        self.sessions.removeAll { $0.id == newId }
        self.sessions.insert(placeholder, at: 0)
        self.selectedSessionId = newId
        self.activeChat.cacheSessionId = newId
        self.persistPrefs()
        PiCache.saveSessions(self.sessions)
      }
      // Reconcile with server in background; don't block prompt.
      Task { @MainActor in
        await self.loadSessions()
        // Ensure selection sticks even if server list lags.
        if self.selectedSessionId != newId {
          self.selectedSessionId = newId
          self.activeChat.cacheSessionId = newId
          self.persistPrefs()
        }
      }
      return newId
    } catch {
      return nil
    }
  }

  /// Refresh sidebar via RPC after any prompt completes. Ensures a just-created
  /// new chat (even when already selected as empty) appears with its updated
  /// title/firstMessage without requiring app reload or another newChat.
  func refreshSessionsAfterPrompt() async {
    // Don't block the chat UI — loadSessions is already MainActor and lightweight.
    await loadSessions()
  }

  /// Called as soon as first token arrives for an unselected new-chat draft.
  /// Triggers an early RPC refresh so the sidebar appears without waiting
  /// for the full stream to complete.
  func handleFirstTokenForNewChat() async {
    guard selectedSessionId == nil, !activeChat.messages.isEmpty else { return }
    // Try to adopt via getState first (more accurate than newest-by-modified).
    do {
      let state = try await rpcClient.getState()
      if let newId = state.data?.sessionId, !newId.isEmpty {
        await adoptNewChatSession(newId)
        return
      }
    } catch {
      // Fallback: just refresh the list; draft preview already shows locally.
    }
    // Fallback: just refresh the list; draft preview already shows locally.
    await loadSessions()
  }

  /// Adopt the server-assigned sessionId for the first turn of a previously
  /// unselected new chat, then refresh the sidebar list.
  func adoptNewChatSession(_ sessionId: String) async {
    guard !sessionId.isEmpty else { return }
    if let selected = selectedSessionId, selected == sessionId { return }
    // Only adopt when we were in the "New chat" (unselected) state.
    // If user already switched to another session during the stream, ignore.
    guard selectedSessionId == nil else { return }
    // Set selection first so draft preview hides and real entry highlights.
    selectedSessionId = sessionId
    activeChat.cacheSessionId = sessionId
    persistPrefs()
    // Refresh list; retry briefly if server hasn't yet listed the new session.
    await loadSessions()
    if !sessions.contains(where: { $0.id == sessionId }) {
      // Server may need a moment to flush the session file after first prompt.
      try? await Task.sleep(for: .milliseconds(600))
      await loadSessions()
    }
    // Re-assert selection even if list still doesn't contain it (avoid clearing).
    if selectedSessionId != sessionId {
      selectedSessionId = sessionId
      activeChat.cacheSessionId = sessionId
      persistPrefs()
    }
    activeChat.persistChatCache(sessionId: sessionId)
  }

  /// Sidebar pre-filled with mock sessions and an active canned chat.
  @MainActor
  static var preview: SidebarStore {
    let store = SidebarStore(connectToServer: false)
    AICodeChatMock.seed(into: store)
    return store
  }

  /// Paint last-known sidebar, models, and open chat before any network call.
  func hydrateFromCache() {
    guard let bootstrap = PiCache.loadBootstrap() else { return }
    if !bootstrap.sessions.isEmpty {
      sessions = bootstrap.sessions
    }
    selectedSessionId = bootstrap.lastSessionId ?? sessions.first?.id
    activeChat.cacheSessionId = selectedSessionId

    activeChat.applyCachedModels(
      bootstrap.models,
      preferredModelId: bootstrap.lastModelId
    )
    activeChat.applyCachedCommands(bootstrap.commands)

    if let chat = bootstrap.chat {
      activeChat.applyCachedSnapshot(
        chat,
        models: bootstrap.models,
        preferredModelId: bootstrap.lastModelId
      )
      // Enforce authoritative title even when cache is stale (previous race
      // could have saved Brave's title under Hi's id). Sidebar list is the
      // source of truth for display name.
      if let sid = selectedSessionId, let session = sessions.first(where: { $0.id == sid }) {
        let authoritative = sessionTitle(session)
        if authoritative != "New chat", !authoritative.isEmpty {
          activeChat.chatTitle = authoritative
        }
      }
    } else if let session = sessions.first(where: { $0.id == selectedSessionId }) {
      activeChat.chatTitle = sessionTitle(session)
    }
  }

  /// Revalidate sessions, models, and the open chat from the server.
  /// Cached UI stays visible until each piece succeeds.
  func refreshFromServer() async {
    isRefreshing = true
    defer { isRefreshing = false }

    await loadSessions()
    await activeChat.loadAvailableModels()
    await activeChat.loadAvailableCommands()
    await syncActiveSession(clearBeforeLoad: false)
    persistPrefs()
  }

  func persistPrefs() {
    PiCache.savePrefs(
      lastSessionId: selectedSessionId,
      lastModelId: activeChat.selectedModel?.id
    )
  }

  var filteredSessions: [SessionInfo] {
    let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if query.isEmpty { return sessions }
    return sessions.filter { sessionTitle($0).lowercased().contains(query) }
  }

  func sessionTitle(_ session: SessionInfo) -> String {
    // For the currently selected session, prefer the live chatTitle so the
    // sidebar updates instantly (before server's firstMessage is persisted).
    if session.id == selectedSessionId {
      let live = activeChat.chatTitle.trimmingCharacters(in: .whitespacesAndNewlines)
      if !live.isEmpty, live != "New chat" {
        return live
      }
    }
    if let name = session.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
      return name
    }
    let text = session.firstMessage ?? "New chat"
    return String(text.prefix(34))
  }

  func sectionTitle(for day: Date) -> String {
    guard day != Date.distantPast else { return "Unknown" }
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    formatter.doesRelativeDateFormatting = true
    return formatter.string(from: day)
  }

  func sessionDay(_ session: SessionInfo) -> Date? {
    let formatters: [ISO8601DateFormatter] = [
      ISO8601DateFormatter(),
      {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
      }(),
      {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate, .withFullTime, .withFractionalSeconds]
        return f
      }()
    ]
    for formatter in formatters {
      if let date = formatter.date(from: session.created) {
        return Calendar.current.startOfDay(for: date)
      }
    }
    return nil
  }

  var groupedSessions: [(day: Date, sessions: [SessionInfo])] {
    let grouped = Dictionary(grouping: filteredSessions) { sessionDay($0) ?? Date.distantPast }
    return grouped
      .sorted { $0.key > $1.key }
      .map { (day: $0.key, sessions: $0.value.sorted { $0.modified > $1.modified }) }
  }

  func loadSessions() async {
    // Capture refresh id to discard stale results if sessions reloaded concurrently.
    do {
      let sessions = try await rpcClient.listSessions()
      let sorted = sessions.sorted { $0.modified > $1.modified }
      await MainActor.run {
        // No animation on refresh — only mutate when the list actually changed.
        if self.sessions != sorted {
          self.sessions = sorted
        }
        // Keep a valid selection; if none (e.g. "New chat"), leave unselected.
        // Do not auto-pick sessions.first — that re-highlights the last chat after newChat.
        if let selected = self.selectedSessionId,
           !sorted.contains(where: { $0.id == selected }) {
          self.selectedSessionId = nil
          // Also clear activeChat title to avoid showing stale title for deleted session.
          if activeChat.cacheSessionId == selected {
            activeChat.chatTitle = "New chat"
            activeChat.cacheSessionId = nil
          }
        }
        PiCache.saveSessions(sorted)
        self.persistPrefs()
      }
    } catch {
      // Keep cached sessions if the server is unreachable.
    }
  }

  func select(session: SessionInfo) async {
    guard session.id != selectedSessionId else { return }

    await MainActor.run {
      withAnimation(.snappy) { selectedSessionId = session.id }
      activeChat.cacheSessionId = session.id
      persistPrefs()

      // Instant paint from cache when available.
      if let cached = PiCache.loadChat(sessionId: session.id) {
        activeChat.applyCachedSnapshot(cached)
        // Authoritative title is from the sessions list (name / firstMessage).
        // Always enforce it immediately — fixes stale cache where a previous
        // race saved the old session's title under the new session's id.
        // Local renames via Header are saved to cache and will be overwritten
        // here on next select, but server `sessionName` (via get_state) will
        // restore it after loadMessages if the rename was propagated.
        let authoritative = sessionTitle(session)
        if authoritative != "New chat", !authoritative.isEmpty {
          activeChat.chatTitle = authoritative
        }
      } else {
        // No cache — clear to the new title while network loads.
        activeChat.messages = []
        activeChat.usedTokens = 0
        activeChat.chatTitle = sessionTitle(session)
        activeChat.isResponding = false
        activeChat.draft = ""
        activeChat.editingMessageId = nil
        activeChat.pastedItems = []
        activeChat.contextFiles = []
        activeChat.includedRepo = nil
        activeChat.workingDir = nil
        activeChat.messageQueue = []
      }
    }

    do {
      // Abort early if user switched again while we were painting.
      guard selectedSessionId == session.id else { return }
      _ = try await rpcClient.switchSession(path: session.path)
      guard selectedSessionId == session.id, activeChat.cacheSessionId == session.id else { return }
      await activeChat.loadMessages(sessionId: session.id)
      persistPrefs()
    } catch {
      // Keep whatever we showed (cache or empty shell).
    }
  }

  func newChat() async {
    // Purely local — no RPC. The server session will be created lazily on
    // the first prompt for this draft, atomically inside streamReply.
    // This eliminates the race where Send could fire before newSession
    // completes and land in the previous session.
    await MainActor.run {
      withAnimation(.snappy) {
        selectedSessionId = nil
        activeChat.cacheSessionId = nil
      }
      persistPrefs()
    }
    await activeChat.resetToSession(title: "New chat")
  }

  func delete(session: SessionInfo) async {
    // The π RPC protocol does not expose a delete-session command.
    // Remove it from the local list only.
    let wasSelected = session.id == selectedSessionId
    await MainActor.run {
      withAnimation(.snappy) {
        sessions.removeAll { $0.id == session.id }
        if wasSelected {
          selectedSessionId = sessions.first?.id
        }
      }
      PiCache.saveSessions(sessions)
      persistPrefs()
    }
    if wasSelected, let next = sessions.first {
      await select(session: next)
    }
  }

  func logout() {
    sessions.removeAll()
    selectedSessionId = nil
    searchText = ""
    activeChat = ChatStore(connectToServer: false, rpcClient: self.rpcClient)
    activeChat.onNewSessionAdopted = { [weak self] newId in
      Task { @MainActor in
        await self?.adoptNewChatSession(newId)
      }
    }
    activeChat.onStreamCompleted = { [weak self] in
      await self?.refreshSessionsAfterPrompt()
    }
    activeChat.onFirstTokenForNewChat = { [weak self] in
      await self?.handleFirstTokenForNewChat()
    }
    activeChat.createServerSessionForDraft = { [weak self] in
      await self?.createServerSessionForDraft()
    }
    PiCache.clearAll()
  }

  /// - Parameter clearBeforeLoad: When `true`, wipe the chat before fetching (legacy).
  ///   Launch refresh uses `false` so cached messages stay visible until RPC returns.
  func syncActiveSession(clearBeforeLoad: Bool = true) async {
    guard let session = sessions.first(where: { $0.id == selectedSessionId }) else { return }
    let expectedId = session.id
    activeChat.cacheSessionId = session.id
    if clearBeforeLoad {
      await activeChat.resetToSession(title: sessionTitle(session))
    } else {
      // Keep cache visible but ensure title matches the active session.
      // Previously only updated when title was "New chat", which left stale
      // titles after a race where cache was saved with the previous session's title.
      let authoritative = sessionTitle(session)
      if authoritative != "New chat", !authoritative.isEmpty, activeChat.chatTitle != authoritative {
        activeChat.chatTitle = authoritative
      }
    }
    do {
      guard selectedSessionId == expectedId else { return }
      _ = try await rpcClient.switchSession(path: session.path)
    } catch {
      // Still attempt get_entries; switch may not be required if already active.
    }
    guard selectedSessionId == expectedId, activeChat.cacheSessionId == expectedId else { return }
    await activeChat.loadMessages(sessionId: session.id)
  }
}

