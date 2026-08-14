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
  var isRefreshing = false

  @ObservationIgnored
  let rpcClient: any PiRPCP

  /// Bumped on every user session change. Async work drops results if it no longer matches.
  @ObservationIgnored
  private var sessionEpoch: UInt64 = 0

  /// Serializes switch_session / new_session / get_entries so rapid taps cannot reorder RPC.
  @ObservationIgnored
  private var rpcTail: Task<Void, Never> = Task {}

  init(connectToServer: Bool = true, rpcClient: any PiRPCP = PiRPCClient()) {
    self.rpcClient = rpcClient
    activeChat = ChatStore(connectToServer: connectToServer, rpcClient: rpcClient)
    bindChatCallbacks()
    guard connectToServer else { return }
    hydrateFromCache()
    Task { @MainActor in
      await refreshFromServer()
    }
  }

  @MainActor
  static var preview: SidebarStore {
    let store = SidebarStore(connectToServer: false)
    AICodeChatMock.seed(into: store)
    return store
  }

  // MARK: - Titles

  func sessionTitle(_ session: SessionInfo) -> String {
    session.displayTitle
  }

  func sectionTitle(for day: Date) -> String {
    guard day != Date.distantPast else { return "Unknown" }
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    formatter.doesRelativeDateFormatting = true
    return formatter.string(from: day)
  }

  // MARK: - List

  var filteredSessions: [SessionInfo] {
    let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if query.isEmpty { return sessions }
    return sessions.filter { $0.displayTitle.lowercased().contains(query) }
  }

  var groupedSessions: [(day: Date, sessions: [SessionInfo])] {
    let grouped = Dictionary(grouping: filteredSessions) { sessionDay($0) ?? Date.distantPast }
    return grouped
      .sorted { $0.key > $1.key }
      .map { (day: $0.key, sessions: $0.value.sorted { $0.modified > $1.modified }) }
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
      }(),
    ]
    for formatter in formatters {
      if let date = formatter.date(from: session.created) {
        return Calendar.current.startOfDay(for: date)
      }
    }
    return nil
  }

  // MARK: - User actions

  func select(session: SessionInfo) async {
    guard session.id != selectedSessionId else { return }
    let epoch = bumpEpoch()
    paint(session: session)

    await withSessionRPC {
      guard epoch == self.sessionEpoch else { return }
      do {
        _ = try await self.rpcClient.switchSession(path: session.path)
      } catch {
        return
      }
      guard epoch == self.sessionEpoch, self.activeChat.cacheSessionId == session.id else { return }
      await self.activeChat.loadMessages(sessionId: session.id)
      guard epoch == self.sessionEpoch else { return }
      if let latest = self.sessions.first(where: { $0.id == session.id }) {
        self.activeChat.chatTitle = latest.displayTitle
      }
    }
  }

  func newChat() async {
    _ = bumpEpoch()
    selectedSessionId = nil
    activeChat.cacheSessionId = nil
    persistPrefs()
    await activeChat.resetToSession(title: "New chat")
  }

  func delete(session: SessionInfo) async {
    let wasSelected = session.id == selectedSessionId
    sessions.removeAll { $0.id == session.id }
    PiCache.saveSessions(sessions)
    if wasSelected {
      if let next = sessions.first {
        await select(session: next)
      } else {
        await newChat()
      }
    } else {
      persistPrefs()
    }
  }

  func logout() {
    sessions.removeAll()
    selectedSessionId = nil
    searchText = ""
    sessionEpoch += 1
    activeChat = ChatStore(connectToServer: false, rpcClient: rpcClient)
    bindChatCallbacks()
    PiCache.clearAll()
  }

  // MARK: - Bootstrap

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
    }
    applyHeaderTitleFromSelectedSession()
  }

  func refreshFromServer() async {
    isRefreshing = true
    defer { isRefreshing = false }

    await loadSessions()
    await activeChat.loadAvailableModels()
    await activeChat.loadAvailableCommands()
    await syncActiveSession()
    persistPrefs()
  }

  func persistPrefs() {
    PiCache.savePrefs(
      lastSessionId: selectedSessionId,
      lastModelId: activeChat.selectedModel?.id
    )
  }

  func loadSessions() async {
    do {
      let listed = try await rpcClient.listSessions()
      let sorted = listed.sorted { $0.modified > $1.modified }
      mergeListedSessions(sorted)
      PiCache.saveSessions(sessions)
      persistPrefs()
    } catch {
      // Keep cached sessions if the server is unreachable.
    }
  }

  func syncActiveSession() async {
    guard let session = sessions.first(where: { $0.id == selectedSessionId }) else { return }
    let epoch = sessionEpoch
    activeChat.cacheSessionId = session.id
    applyHeaderTitleFromSelectedSession()

    await withSessionRPC {
      guard epoch == self.sessionEpoch else { return }
      do {
        _ = try await self.rpcClient.switchSession(path: session.path)
      } catch {
        // get_entries may still work if this session is already active.
      }
      guard epoch == self.sessionEpoch, self.activeChat.cacheSessionId == session.id else { return }
      await self.activeChat.loadMessages(sessionId: session.id)
      guard epoch == self.sessionEpoch else { return }
      self.applyHeaderTitleFromSelectedSession()
    }
  }

  // MARK: - Draft session (first send)

  /// Only caller of `new_session` for a local draft. Returns nil if the user left the draft.
  func createServerSessionForDraft() async -> String? {
    let epoch = sessionEpoch
    let title = draftTitle()

    return await withSessionRPC {
      guard epoch == self.sessionEpoch, self.selectedSessionId == nil else { return nil }
      do {
        _ = try await self.rpcClient.newSession()
        let state = try await self.rpcClient.getState()
        guard epoch == self.sessionEpoch, self.selectedSessionId == nil else { return nil }
        guard let newId = state.data?.sessionId, !newId.isEmpty,
              let path = state.data?.sessionFile, !path.isEmpty else { return nil }

        let now = ISO8601DateFormatter().string(from: Date())
        let placeholder = SessionInfo(
          path: path,
          id: newId,
          cwd: "",
          name: nil,
          created: now,
          modified: now,
          messageCount: 1,
          firstMessage: title,
          allMessagesText: title
        )
        self.upsert(placeholder)
        self.selectedSessionId = newId
        self.activeChat.cacheSessionId = newId
        self.activeChat.chatTitle = placeholder.displayTitle
        self.persistPrefs()
        PiCache.saveSessions(self.sessions)

        Task { @MainActor in
          await self.loadSessions()
        }
        return newId
      } catch {
        return nil
      }
    }
  }

  /// Remote-folder / cwd prompt path: server already created a session, draft still unselected.
  func adoptDraftSession(_ sessionId: String) async {
    guard !sessionId.isEmpty, selectedSessionId == nil else { return }
    let epoch = sessionEpoch
    let title = draftTitle()

    await withSessionRPC {
      guard epoch == self.sessionEpoch, self.selectedSessionId == nil else { return }
      let path: String
      do {
        let state = try await self.rpcClient.getState()
        guard epoch == self.sessionEpoch, self.selectedSessionId == nil else { return }
        guard state.data?.sessionId == sessionId,
              let file = state.data?.sessionFile, !file.isEmpty else { return }
        path = file
      } catch {
        return
      }
      let now = ISO8601DateFormatter().string(from: Date())
      let placeholder = SessionInfo(
        path: path,
        id: sessionId,
        cwd: "",
        name: nil,
        created: now,
        modified: now,
        messageCount: 1,
        firstMessage: title,
        allMessagesText: title
      )
      self.upsert(placeholder)
      self.selectedSessionId = sessionId
      self.activeChat.cacheSessionId = sessionId
      self.activeChat.chatTitle = placeholder.displayTitle
      self.persistPrefs()
      PiCache.saveSessions(self.sessions)
    }
  }

  // MARK: - Private

  private func bindChatCallbacks() {
    activeChat.onNewSessionAdopted = { [weak self] newId in
      Task { @MainActor in
        await self?.adoptDraftSession(newId)
      }
    }
    activeChat.onStreamCompleted = { [weak self] in
      await self?.loadSessions()
    }
    activeChat.createServerSessionForDraft = { [weak self] in
      await self?.createServerSessionForDraft()
    }
    activeChat.onDisplayTitleChanged = { [weak self] title, isRename in
      self?.applyLocalTitle(title, isRename: isRename)
    }
  }

  private func bumpEpoch() -> UInt64 {
    sessionEpoch += 1
    return sessionEpoch
  }

  private func withSessionRPC<T: Sendable>(_ operation: @escaping @MainActor () async -> T) async -> T {
    let previous = rpcTail
    let task = Task { @MainActor in
      await previous.value
      return await operation()
    }
    rpcTail = Task { _ = await task.value }
    return await task.value
  }

  private func paint(session: SessionInfo) {
    selectedSessionId = session.id
    activeChat.cacheSessionId = session.id
    persistPrefs()

    if let cached = PiCache.loadChat(sessionId: session.id) {
      activeChat.applyCachedSnapshot(cached)
    } else {
      activeChat.messages = []
      activeChat.usedTokens = 0
      activeChat.isResponding = false
      activeChat.draft = ""
      activeChat.editingMessageId = nil
      activeChat.pastedItems = []
      activeChat.contextFiles = []
      activeChat.includedRepo = nil
      activeChat.workingDir = nil
      activeChat.messageQueue = []
    }
    activeChat.chatTitle = session.displayTitle
  }

  private func applyHeaderTitleFromSelectedSession() {
    if let session = sessions.first(where: { $0.id == selectedSessionId }) {
      activeChat.chatTitle = session.displayTitle
    } else if selectedSessionId == nil {
      if activeChat.messages.isEmpty {
        activeChat.chatTitle = "New chat"
      }
    }
  }

  private func draftTitle() -> String {
    let live = activeChat.chatTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    if !live.isEmpty, live != "New chat" { return live }
    if let first = activeChat.messages.first(where: { $0.role == .user })?.text, !first.isEmpty {
      return String(first.prefix(34))
    }
    return "New chat"
  }

  private func applyLocalTitle(_ title: String, isRename: Bool) {
    let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    guard let id = selectedSessionId ?? activeChat.cacheSessionId,
          let index = sessions.firstIndex(where: { $0.id == id }) else {
      activeChat.chatTitle = trimmed
      return
    }
    let updated: SessionInfo
    if isRename {
      updated = sessions[index].replacing(name: trimmed)
    } else if sessions[index].name == nil {
      updated = sessions[index].replacing(firstMessage: trimmed)
    } else {
      updated = sessions[index]
    }
    sessions[index] = updated
    if id == selectedSessionId || id == activeChat.cacheSessionId {
      activeChat.chatTitle = updated.displayTitle
    }
    PiCache.saveSessions(sessions)
  }

  private func upsert(_ session: SessionInfo) {
    sessions.removeAll { $0.id == session.id }
    sessions.insert(session, at: 0)
  }

  /// Keep local name/firstMessage when the server list has not caught up yet.
  /// Never clear the current selection just because the file is not listed yet.
  private func mergeListedSessions(_ incoming: [SessionInfo]) {
    let localById = Dictionary(uniqueKeysWithValues: sessions.map { ($0.id, $0) })
    var merged: [SessionInfo] = incoming.map { server in
      guard let local = localById[server.id] else { return server }
      let name = nonempty(server.name) ?? nonempty(local.name)
      let first = nonempty(server.firstMessage) ?? nonempty(local.firstMessage)
      return SessionInfo(
        path: server.path,
        id: server.id,
        cwd: server.cwd,
        name: name,
        created: server.created,
        modified: server.modified,
        messageCount: server.messageCount,
        firstMessage: first,
        allMessagesText: server.allMessagesText
      )
    }
    if let selected = selectedSessionId,
       !merged.contains(where: { $0.id == selected }),
       let local = localById[selected] {
      merged.insert(local, at: 0)
    }
    sessions = merged.sorted { $0.modified > $1.modified }
    applyHeaderTitleFromSelectedSession()
  }

  private func nonempty(_ value: String?) -> String? {
    guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
      return nil
    }
    return value
  }
}
