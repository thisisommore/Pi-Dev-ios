//
//  AICodeChat.page+Controller.swift
//  Pi Dev
//

import Observation
import SwiftUI

@MainActor
@Observable
final class ChatStore: Identifiable {
  let id = UUID()
  var messages: [ChatMessage] = []
  var selectedModel: AgentModel? = nil
  var availableModels: [AgentModel] = []
  var availableCommands: [PiCommand] = []
  var thinkingLevel: ThinkingLevel = .high
  var supportedThinkingLevels: [ThinkingLevel] = ThinkingLevel.defaultLevels
  var usedTokens: Int = 0
  var draft: String = ""
  var isResponding = false
  var chatTitle = "New chat"
  var editingMessageId: UUID? = nil
  var pastedItems: [PastedItem] = []
  var contextFiles: [ContextFile] = []
  var includedRepo: IncludedRepo? = nil
  var messageQueue: [String] = []
  /// Session id used when writing chat cache (owned by SidebarStore).
  var cacheSessionId: String? = nil
  /// Called when the first turn of a new (previously unselected) chat commits on the server.
  /// SidebarStore sets this to adopt the new sessionId and refresh the list.
  var onNewSessionAdopted: ((String) -> Void)?

  private let rpcClient = PiRPCClient()

  var contextFraction: Double {
    min(1, Double(usedTokens) / Double(selectedModel?.contextWindow ?? 200_000))
  }

  var isStreaming: Bool { messages.contains { $0.isStreaming } }
  var generatingMessageId: UUID? = nil
  var isGenerating: Bool { isResponding || isStreaming }
  private var stopRequested = false

  // Stable UUID per queue entry — avoids ForEach diff glitches when removing by offset.
  private var queuedMessageIDs: [UUID] = []

  var queuedMessagesForDisplay: [QueuedMessage] {
    // Sync ID array with queue count (preserve existing IDs for stable diff).
    if queuedMessageIDs.count != messageQueue.count {
      if queuedMessageIDs.count < messageQueue.count {
        queuedMessageIDs.append(contentsOf: (queuedMessageIDs.count..<messageQueue.count).map { _ in UUID() })
      } else {
        queuedMessageIDs.removeLast(queuedMessageIDs.count - messageQueue.count)
      }
    }
    return messageQueue.enumerated().reversed().map { idx, text in
      QueuedMessage(id: queuedMessageIDs[idx], text: text, queueIndex: idx)
    }
  }

  /// - Parameter connectToServer: When `false`, skip RPC bootstrap (previews / offline mocks).
  init(connectToServer: Bool = true) {
    guard connectToServer else { return }
    // Models hydrate via SidebarStore.bootstrap; still refresh in background.
    Task { @MainActor in
      await loadAvailableModels()
      await loadAvailableCommands()
    }
  }

  /// Apply a cached chat snapshot immediately (no network).
  func applyCachedSnapshot(_ snapshot: CachedChatSnapshot, models: [AgentModel] = [], preferredModelId: String? = nil) {
    messages = snapshot.messages
    usedTokens = snapshot.usedTokens
    chatTitle = snapshot.title
    thinkingLevel = ThinkingLevel(id: snapshot.thinkingLevel)
    isResponding = false
    draft = ""
    editingMessageId = nil
    pastedItems = []
    contextFiles = []
    includedRepo = nil
    messageQueue = []
    generatingMessageId = nil

    if !models.isEmpty {
      availableModels = models
    }
    // Only restore a known selection — never invent models.first.
    let modelId = preferredModelId ?? snapshot.selectedModelId
    if let modelId, let match = availableModels.first(where: { $0.id == modelId }) {
      selectedModel = match
    }
  }

  func applyCachedModels(_ models: [AgentModel], preferredModelId: String? = nil) {
    guard !models.isEmpty else { return }
    availableModels = models
    if let preferredModelId, let match = models.first(where: { $0.id == preferredModelId }) {
      selectedModel = match
    } else if let selected = selectedModel,
              !models.contains(where: { $0.id == selected.id }) {
      // Cached selection no longer offered by this server.
      selectedModel = nil
    }
    // Otherwise leave nil so the UI shows "Model" until get_state / user pick.
  }

  func applyCachedCommands(_ commands: [PiCommand]) {
    guard !commands.isEmpty else { return }
    if availableCommands != commands {
      availableCommands = commands
    }
  }

  func loadAvailableCommands() async {
    do {
      let response = try await rpcClient.getCommands()
      if let commands = response.data?.commands {
        if self.availableCommands != commands {
          self.availableCommands = commands
        }
        PiCache.saveCommands(commands)
      }
    } catch {
      // Keep cached commands if fetch fails.
    }
  }

  /// Filters commands for autocomplete based on the current draft.
  /// Supports leading "/" (e.g. "/fix") and inline trailing "/xyz".
  /// Hidden once the slash token is completed with a trailing space.
  func filteredCommands(for draft: String) -> [PiCommand] {
    guard !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
    if editingMessageId != nil { return [] }

    // Use left-trimmed version to preserve trailing space info (trimming only leading spaces).
    let leftTrimmed = draft.replacingOccurrences(of: "^\\s+", with: "", options: .regularExpression)
    guard !leftTrimmed.isEmpty else { return [] }

    let query: String
    if leftTrimmed.hasPrefix("/") {
      let afterSlash = String(leftTrimmed.dropFirst())
      if let spaceIdx = afterSlash.firstIndex(where: { $0.isWhitespace }) {
        // There's whitespace after the slash token — user has typed args or trailing space.
        // Hide suggestions once token is separated (completed or abandoned).
        let token = String(afterSlash[..<spaceIdx])
        // Still hide regardless of exact match; slash token is no longer active editing.
        // But keep showing if token is empty? No, spaceIdx at start would be empty token.
        if token.isEmpty { return [] }
        return []
      } else {
        query = afterSlash
      }
    } else {
      // Look for trailing "/xyz" token at end of draft.
      // If draft ends with whitespace, user finished the token -> hide.
      if leftTrimmed.last?.isWhitespace == true { return [] }
      // Find last "/" preceded by whitespace or start, with no whitespace after.
      // Use last whitespace-separated token that starts with "/"
      let tokens = leftTrimmed.split(whereSeparator: { $0.isWhitespace })
      guard let last = tokens.last, last.hasPrefix("/") else { return [] }
      var afterSlash = String(last.dropFirst())
      if afterSlash.contains("\n") {
        afterSlash = afterSlash.components(separatedBy: "\n").last ?? ""
      }
      query = afterSlash
    }

    let lower = query.lowercased()
    let candidates: [PiCommand]
    if lower.isEmpty {
      candidates = availableCommands
    } else {
      candidates = availableCommands.filter {
        $0.name.lowercased().contains(lower) ||
        ($0.description?.lowercased().contains(lower) ?? false)
      }
    }

    let sorted = candidates.sorted { a, b in
      let aLower = a.name.lowercased()
      let bLower = b.name.lowercased()
      let aPrefix = aLower.hasPrefix(lower)
      let bPrefix = bLower.hasPrefix(lower)
      if aPrefix != bPrefix { return aPrefix && !bPrefix }
      return aLower < bLower
    }
    return Array(sorted.prefix(8))
  }

  /// Applies a command suggestion to the draft, replacing the slash token.
  func applyCommand(_ command: PiCommand) {
    let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.hasPrefix("/") {
      let afterSlash = String(trimmed.dropFirst())
      if let spaceIdx = afterSlash.firstIndex(where: { $0.isWhitespace }) {
        let remainder = String(afterSlash[spaceIdx...]) // includes space + rest
        draft = "/" + command.name + remainder
      } else {
        draft = "/" + command.name + " "
      }
    } else {
      // Replace last "/xyz" token
      // Find last occurrence of " /"
      if let range = trimmed.range(of: "/", options: .backwards) {
        let before = String(trimmed[..<range.lowerBound])
        draft = before + "/" + command.name + " "
      } else {
        draft = "/" + command.name + " "
      }
    }
  }

  func loadAvailableModels() async {
    do {
      let response = try await rpcClient.getAvailableModels()
            if let models = response.data?.models, !models.isEmpty {
        // Background refresh: no animation; skip assign when unchanged.
        if self.availableModels != models {
          self.availableModels = models
        }
        // Never auto-pick the first model — stay unselected until server state
        // (apply) or an explicit user choice provides the real selection.
        if let selected = self.selectedModel,
           !models.contains(where: { $0.id == selected.id }) {
          self.selectedModel = nil
        }
        PiCache.saveModels(models)
        if let id = selectedModel?.id {
          PiCache.saveLastModelId(id)
        }
      } else {
              }
    } catch {
            // Keep cached models if the server is unreachable.
    }
  }

  func selectModel(_ model: AgentModel) async {
    do {
      _ = try await rpcClient.setModel(provider: model.provider ?? "", modelId: model.id)
      await MainActor.run {
        withAnimation(.snappy) { self.selectedModel = model }
      }
      PiCache.saveLastModelId(model.id)
      await syncStateFromServer()
    } catch {
      await MainActor.run {
        withAnimation(.snappy) { self.selectedModel = model }
      }
      PiCache.saveLastModelId(model.id)
    }
  }

  func selectRepo(_ repo: IncludedRepo) {
    withAnimation(.snappy) { self.includedRepo = repo }
  }

  func clearRepo() {
    withAnimation(.snappy) { self.includedRepo = nil }
  }

  func resetToSession(title: String) async {
    await MainActor.run {
      withAnimation(.snappy) {
        messages = []
        usedTokens = 0
        chatTitle = title
        isResponding = false
        draft = ""
        editingMessageId = nil
        pastedItems = []
        contextFiles = []
        includedRepo = nil
        messageQueue = []
      }
    }
  }

  func renameSession(to newTitle: String) async {
    let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, trimmed != chatTitle else { return }
    let oldTitle = chatTitle
    // Optimistic update for instant UI.
    chatTitle = trimmed
    do {
      _ = try await rpcClient.setSessionName(trimmed)
      // Persist locally and refresh server state (sessionName).
      persistChatCache()
      await syncStateFromServer()
    } catch {
      // Revert on failure — keep cache consistent.
      chatTitle = oldTitle
      // Also try to inform user via error? For now silent revert.
    }
  }

  private func buildSupportedThinkingLevels(from map: [String: String?]?) -> [ThinkingLevel] {
    var levels = ThinkingLevel.defaultLevels.filter { level in
      guard let map, let entry = map[level.id] else { return true }
      return entry != nil
    }

    if let map {
      let extras = map.compactMap { key, value -> ThinkingLevel? in
        guard value != nil, !ThinkingLevel.defaultLevels.contains(where: { $0.id == key }) else { return nil }
        return ThinkingLevel(id: key)
      }
      levels.append(contentsOf: extras.sorted { $0.id < $1.id })
    }

    return levels
  }

  private func apply(state: AgentState) {
    // Server is source of truth for the active model.
    if let model = state.model {
      if selectedModel != model {
        self.selectedModel = model
      }
      PiCache.saveLastModelId(model.id)
    }
    if let levelString = state.thinkingLevel {
      let level = ThinkingLevel(id: levelString)
      if thinkingLevel != level {
        self.thinkingLevel = level
      }
    }
    if let name = state.sessionName?.trimmingCharacters(in: .whitespacesAndNewlines),
       !name.isEmpty,
       chatTitle != name {
      self.chatTitle = name
    }
    let levels = self.buildSupportedThinkingLevels(from: state.model?.thinkingLevelMap)
    if supportedThinkingLevels.map(\.id) != levels.map(\.id) {
      self.supportedThinkingLevels = levels
    }
  }

  private func syncStateFromServer() async {
    do {
      let state = try await rpcClient.getState()
      await MainActor.run {
        // No animation — state sync runs on refresh and after streams.
        // Guard against stale state (user switched sessions while fetching).
        if let stateData = state.data, let sid = stateData.sessionId, let cached = self.cacheSessionId, sid != cached {
          return
        }
        if let stateData = state.data {
          self.apply(state: stateData)
        }
      }
    } catch {
      // Keep existing levels if the server is unreachable.
    }
  }

  /// Loads messages from the server and replaces the in-memory list.
  /// On failure, existing (cached) messages are left untouched.
  /// - Parameter sessionId: When set, persists the loaded transcript under this session.
  func loadMessages(sessionId: String? = nil) async {
    // Capture target at call time to detect stale completions after a session switch.
    let targetId = sessionId ?? cacheSessionId
    do {
      let response = try await rpcClient.getEntries()
      guard let entries = response.data?.entries else { return }

      // Collect toolResult outputs keyed by toolCallId so assistant messages can be rehydrated with terminal output.
      var toolResults: [String: (output: String, isError: Bool)] = [:]
      for entry in entries {
        guard entry.type == "message", let msg = entry.message, let role = msg.role, role == "toolResult", let toolCallId = msg.toolCallId else { continue }
        let output = msg.content?.textBlocks().joined(separator: "\n") ?? ""
        let isError = msg.isError ?? false
        toolResults[toolCallId] = (output, isError)
      }

      let chatMessages = entries.compactMap { entry -> ChatMessage? in
        guard entry.type == "message", let agentMessage = entry.message else { return nil }
        guard let role = agentMessage.role else { return nil }
        let text = agentMessage.content?.textBlocks().joined(separator: "\n\n") ?? ""

        if role == "user" {
          return ChatMessage(entryId: entry.id, role: .user, text: text, tokens: 0)
        } else if role == "assistant" {
          var message = ChatMessage(entryId: entry.id, role: .assistant, text: text, tokens: 0)
          self.populate(message: &message, from: agentMessage, toolResults: toolResults)
          return message
        }
        return nil
      }

      let state = try await rpcClient.getState()
      let tokens = chatMessages.reduce(0) { $0 + $1.tokens }
      await MainActor.run {
        // Discard stale results if user switched sessions while we were fetching.
        if let targetId, self.cacheSessionId != targetId { return }
        // Also discard if server state belongs to a different session.
        if let sid = state.data?.sessionId, let cached = self.cacheSessionId, sid != cached { return }

        // Background revalidate: only replace when content actually differs.
        // Avoids ForEach re-insert animations from fresh UUIDs on every load.
        if !ChatMessage.contentMatches(self.messages, chatMessages) {
          self.messages = chatMessages
        }
        if self.usedTokens != tokens {
          self.usedTokens = tokens
        }
        if let stateData = state.data {
          self.apply(state: stateData)
        }
        if let sessionId {
          // Only persist if still the active session.
          if self.cacheSessionId == sessionId {
            self.persistChatCache(sessionId: sessionId)
          }
        }
      }
    } catch {
      // Keep cached / existing messages if the server is unreachable.
    }
  }

  func persistChatCache(sessionId: String? = nil) {
    let id = sessionId ?? cacheSessionId
    guard let id, !id.isEmpty, !isStreaming else { return }
    PiCache.saveChat(
      sessionId: id,
      title: chatTitle,
      usedTokens: usedTokens,
      selectedModelId: selectedModel?.id,
      thinkingLevel: thinkingLevel,
      messages: messages
    )
  }

  private func populate(message: inout ChatMessage, from agentMessage: AgentMessage, toolResults: [String: (output: String, isError: Bool)] = [:]) {
    if let usage = agentMessage.usage {
      message.tokens = usage.totalTokens ?? ((usage.input ?? 0) + (usage.output ?? 0))
    }

    if let errorMessage = agentMessage.errorMessage, !errorMessage.isEmpty {
      message.error = errorMessage
    }

    if let thinkingText = agentMessage.content?.thinkingBlocks().joined(separator: "\n\n"), !thinkingText.isEmpty {
      message.thinking = Thinking(summary: thinkingText, truncated: thinkingText, full: thinkingText, seconds: 0)
    }

    let toolCalls = agentMessage.content?.toolCalls() ?? []
    // Rehydrate terminal output from persisted toolResult entries (for history reload after restart).
    // Best practice: for bash, terminal (command+output) is the single source of truth — suppress duplicate ToolChip.
    var terminalRuns: [TerminalRun] = []
    var terminalByCallId: [String: TerminalRun] = [:]
    for call in toolCalls where call.name.lowercased().contains("bash") {
      guard let callId = call.id, let result = toolResults[callId] else { continue }
      let command = (call.arguments?["command"]?.value as? String) ?? formatToolDetail(name: call.name, arguments: call.arguments)
      if command.isEmpty && result.output.isEmpty { continue }
      let run = TerminalRun(command: command, output: result.output, exitCode: result.isError ? 1 : 0)
      terminalRuns.append(run)
      terminalByCallId[callId] = run
    }
    message.terminal = terminalRuns

    // For bash with terminal available, the TerminalBlock alone represents the execution (command + output + exitCode).
    // Keep ToolChip only for non-bash tools to avoid duplicate command display.
    let filteredToolCalls = toolCalls.filter { call in
      if call.name.lowercased().contains("bash"), let cid = call.id, terminalByCallId[cid] != nil {
        return false
      }
      return true
    }
    message.tools = filteredToolCalls.map { call in
      let detail = formatToolDetail(name: call.name, arguments: call.arguments)
      return ToolUse(kind: toolKind(for: call.name), name: call.name, detail: detail, symbol: toolSymbol(for: call.name), callId: call.id)
    }

    if let built = buildSegments(from: agentMessage.content) {
      var segments = built.segments
      // Remove duplicate bash tool segments where terminal will be shown instead.
      segments = segments.filter { seg in
        if case .tool(let tool) = seg, tool.name.lowercased().contains("bash"), let cid = tool.callId, terminalByCallId[cid] != nil {
          return false
        }
        return true
      }
      // Append terminal blocks in original toolCall order (preserves interleaving with non-bash tools).
      for call in toolCalls where call.name.lowercased().contains("bash") {
        guard let callId = call.id, let run = terminalByCallId[callId] else { continue }
        segments.append(.terminal(run))
      }
      message.segments = segments
      message.text = built.text
      message.code = built.code
    } else {
      let (textWithoutCode, code) = stripFirstCodeBlock(from: message.text)
      message.code = code
      message.text = textWithoutCode.trimmingCharacters(in: .whitespacesAndNewlines)
      if !terminalRuns.isEmpty {
        message.segments = terminalRuns.map { .terminal($0) }
      }
    }
  }

  func newChat() {
    withAnimation(.snappy) {
      messages = []
      usedTokens = 0
      chatTitle = "New chat"
      isResponding = false
      draft = ""
      editingMessageId = nil
      pastedItems = []
      contextFiles = []
      includedRepo = nil
      messageQueue = []
    }
  }

  func forkChat() {
    withAnimation(.snappy) {
      chatTitle = chatTitle + " (fork)"
      isResponding = false
      draft = ""
      editingMessageId = nil
      pastedItems = []
      contextFiles = []
      includedRepo = nil
      messageQueue = []
    }
  }

  func startEditing(message: ChatMessage) {
    editingMessageId = message.id
    draft = message.text
  }

  func cancelEdit() {
    editingMessageId = nil
    draft = ""
  }

  func cancelEditIfUnchanged() {
    guard let id = editingMessageId,
          let index = messages.firstIndex(where: { $0.id == id }),
          messages[index].text == draft else { return }
    cancelEdit()
  }

  func send() {
    let body = composeBody()
    let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }

    if let id = editingMessageId {
      guard let index = messages.firstIndex(where: { $0.id == id }) else { return }

      updateMessage(at: index) { $0.text = trimmed }

      withAnimation(.snappy) {
        if messages.indices.contains(index + 1) {
          messages.removeSubrange((index + 1)...)
        }
        editingMessageId = nil
        draft = ""
        pastedItems = []
        contextFiles = []
        isResponding = true
      }

      Task { @MainActor in
        await streamRerun(message: trimmed, entryId: messages[index].entryId, userMessageIndex: index)
      }
      return
    }

    let repo = includedRepo
    draft = ""
    pastedItems = []
    contextFiles = []

    if isResponding || isStreaming {
      withAnimation(.snappy) {
        messageQueue.append(trimmed)
      }
      return
    }

    sendNow(trimmed, repo: repo)
  }

  private func composeBody() -> String {
    let pastedBody = pastedItems.map(\.content).joined(separator: "\n\n")
    let fileBody = contextFiles.map { "File: \($0.name)\n\($0.content)" }.joined(separator: "\n\n")
    let attachmentsBody = [pastedBody, fileBody].filter { !$0.isEmpty }.joined(separator: "\n\n")
    return [draft, attachmentsBody].filter { !$0.isEmpty }.joined(separator: "\n\n")
  }

  private func sendNow(_ text: String, repo: IncludedRepo? = nil) {
    if messages.isEmpty { chatTitle = String(text.prefix(34)) }

    withAnimation(.snappy) {
      messages.append(ChatMessage(role: .user, text: text, tokens: 180))
      usedTokens += 180
      isResponding = true
    }

    Task { @MainActor in
      await streamReply(for: text, repo: repo)
    }
  }

  func stopGeneration() {
    guard isGenerating else { return }
    stopRequested = true
    // Immediate UI feedback: halt spinners and mark partial content.
    isResponding = false
    for idx in messages.indices where messages[idx].isStreaming {
      messages[idx].isStreaming = false
      if messages[idx].error == nil {
        messages[idx].error = "Generation stopped"
      }
    }
    generatingMessageId = nil
    rpcClient.cancel()
    Task { [weak self] in
      guard let self else { return }
      do {
        _ = try await self.rpcClient.abort()
      } catch {
      }
      await self.syncStateFromServer()
      await MainActor.run {
        self.persistChatCache()
      }
    }
  }

  private func isAbortError(_ text: String?) -> Bool {
    guard let text else { return false }
    return text.lowercased().contains("abort")
  }

  private func processQueue() {
    if stopRequested {
      stopRequested = false
      return
    }
    guard !messageQueue.isEmpty, !isResponding, !isStreaming else { return }
    let next = messageQueue.removeFirst()
    if queuedMessageIDs.indices.contains(0) {
      queuedMessageIDs.remove(at: 0)
    }
    sendNow(next, repo: includedRepo)
  }

  func removeQueuedMessage(at index: Int) {
    guard messageQueue.indices.contains(index) else { return }
    _ = withAnimation(.snappy) {
      messageQueue.remove(at: index)
      if queuedMessageIDs.indices.contains(index) {
        queuedMessageIDs.remove(at: index)
      }
    }
  }

  func removeQueuedMessage(id: UUID) {
    guard let display = queuedMessagesForDisplay.first(where: { $0.id == id }) else { return }
    removeQueuedMessage(at: display.queueIndex)
  }

  func retry(from assistantMessageId: UUID) {
    guard let assistantIndex = messages.firstIndex(where: { $0.id == assistantMessageId }),
          assistantIndex > 0,
          messages[assistantIndex - 1].role == .user else { return }

    let userMessage = messages[assistantIndex - 1]

    withAnimation(.snappy) {
      messages.removeSubrange(assistantIndex...)
      isResponding = true
    }

    Task { @MainActor in
      await streamRerun(message: userMessage.text, entryId: userMessage.entryId, userMessageIndex: assistantIndex - 1)
    }
  }

  func retryWithDifferentSettings(from assistantMessageId: UUID) {
    guard let assistantIndex = messages.firstIndex(where: { $0.id == assistantMessageId }),
          assistantIndex > 0,
          messages[assistantIndex - 1].role == .user else { return }

    let userMessage = messages[assistantIndex - 1]
    startEditing(message: userMessage)
  }


  private func streamReply(for userText: String, repo: IncludedRepo? = nil) async {
    if stopRequested {
      stopRequested = false
      isResponding = false
      generatingMessageId = nil
      return
    }
    let streamSessionId = self.cacheSessionId
    let messageIndex = self.messages.count

    withAnimation(.snappy) {
      self.messages.append(ChatMessage(role: .assistant, text: "", tokens: 0, isStreaming: true))
      self.isResponding = false
    }
    self.generatingMessageId = self.messages[messageIndex].id

    do {
      try await rpcClient.setThinkingLevel(thinkingLevel)
    } catch {
    }

    let userMessageIndex = messageIndex - 1
    await consumeStreamEvents(
      rpcClient.streamEvents(
        forPrompt: userText,
        repo: repo?.url,
        onEntryId: { [weak self] entryId in
          guard let self, let entryId = entryId else { return }
          // Discard entryId for stale session.
          guard self.cacheSessionId == streamSessionId else { return }
          self.updateMessage(at: userMessageIndex) { $0.entryId = entryId }
        }
      ),
      at: messageIndex,
      expectedSessionId: streamSessionId
    )
  }

  private func streamRerun(message: String? = nil, entryId: String? = nil, userMessageIndex: Int? = nil) async {
    if stopRequested {
      stopRequested = false
      isResponding = false
      generatingMessageId = nil
      return
    }
    let streamSessionId = self.cacheSessionId
    let messageIndex = self.messages.count

    withAnimation(.snappy) {
      self.messages.append(ChatMessage(role: .assistant, text: "", tokens: 0, isStreaming: true))
      self.isResponding = false
    }
    self.generatingMessageId = self.messages[messageIndex].id

    do {
      try await rpcClient.setThinkingLevel(thinkingLevel)
    } catch {
    }

    await consumeStreamEvents(
      rpcClient.streamRerunEvents(
        message: message,
        entryId: entryId,
        onEntryId: { [weak self] returnedEntryId in
          guard let self, let userMessageIndex = userMessageIndex, let returnedEntryId = returnedEntryId else { return }
          guard self.cacheSessionId == streamSessionId else { return }
          self.updateMessage(at: userMessageIndex) { $0.entryId = returnedEntryId }
        }
      ),
      at: messageIndex,
      expectedSessionId: streamSessionId
    )
  }

  private func consumeStreamEvents(_ events: AsyncStream<AgentEvent>, at messageIndex: Int, expectedSessionId: String? = nil) async {
    var latestToolNames: [String: String] = [:]
    var latestToolCommands: [String: String] = [:]
    var thinkingStartTime: Date?
    var currentIndex = messageIndex
    var finalizedCurrentTurn = false

    func updateThinkingSeconds() {
      guard let start = thinkingStartTime else { return }
      let elapsed = Date().timeIntervalSince(start)
      updateMessage(at: currentIndex) {
        if $0.thinking == nil {
          $0.thinking = Thinking(summary: "", truncated: "", full: "", seconds: 0)
        }
        $0.thinking?.seconds = elapsed
      }
    }

    for await event in events {
      // Abort if user switched sessions mid-stream — prevents cross-session pollution.
      if let expectedSessionId, self.cacheSessionId != expectedSessionId {
        rpcClient.cancel()
        break
      }
      guard self.messages.indices.contains(currentIndex) else {
        break
      }

      switch event {
      case .agentStart:
        updateMessage(at: currentIndex) { $0.isStreaming = true }

      case .messageStart(let message):
        if message.role == "assistant" {
          // If we manually stopped, the server's follow-up abort turn should be ignored
          // to avoid a second empty "Request was aborted." message.
          if stopRequested {
            break
          }
          // Each agent turn gets its own assistant message, mirroring how
          // history loading maps one ChatMessage per assistant entry.
          let current = self.messages[currentIndex]
          let hasContent = !current.text.isEmpty || current.thinking != nil || !current.tools.isEmpty || current.error != nil
          if hasContent {
            updateMessage(at: currentIndex) { $0.isStreaming = false }
            withAnimation(.snappy) {
              self.messages.append(ChatMessage(role: .assistant, text: "", tokens: 0, isStreaming: true))
            }
            currentIndex = self.messages.count - 1
          } else {
            updateMessage(at: currentIndex) { $0.isStreaming = true }
          }
          thinkingStartTime = nil
          finalizedCurrentTurn = false
        } else {
          updateMessage(at: currentIndex) { $0.isStreaming = true }
        }

      case .messageUpdate(_, let delta):
        switch delta {
        case .textDelta(_, let text):
                    updateMessage(at: currentIndex) {
            $0.text += text
            if let lastIndex = $0.segments.indices.last,
               case .text(let segmentId, let existing) = $0.segments[lastIndex] {
              $0.segments[lastIndex] = .text(id: segmentId, text: existing + text)
            } else {
              $0.segments.append(.text(text: text))
            }
          }
        case .thinkingStart:
          thinkingStartTime = Date()
          updateMessage(at: currentIndex) {
            if $0.thinking == nil {
              $0.thinking = Thinking(summary: "", truncated: "", full: "", seconds: 0)
            }
          }
        case .thinkingDelta(_, let text):
          updateMessage(at: currentIndex) {
            if $0.thinking == nil {
              $0.thinking = Thinking(summary: "", truncated: "", full: "", seconds: 0)
            }
            $0.thinking?.summary += text
            $0.thinking?.full += text
          }
          updateThinkingSeconds()
        case .thinkingEnd:
          updateThinkingSeconds()
        case .toolCallEnd(_, let call):
          let detail = formatToolDetail(name: call.name, arguments: call.arguments)
          updateMessage(at: currentIndex) {
            let tool = ToolUse(
              kind: toolKind(for: call.name),
              name: call.name,
              detail: detail,
              symbol: toolSymbol(for: call.name),
              callId: call.id
            )
            $0.tools.append(tool)
            $0.segments.append(.tool(tool))
          }
          if let id = call.id {
            latestToolNames[id] = call.name
            if let cmd = call.arguments?["command"]?.value as? String, !cmd.isEmpty {
              latestToolCommands[id] = cmd
            } else if !detail.isEmpty {
              latestToolCommands[id] = detail
            }
          }
        case .error(let reason):
          if stopRequested && isAbortError(reason) {
            break
          }
          updateMessage(at: currentIndex) { $0.error = reason }
        default:
          break
        }

      case .toolExecutionEnd(let toolCallId, let toolName, let result, let isError):
        let name = latestToolNames[toolCallId] ?? toolName
        if name.lowercased().contains("bash") {
          let command = (result.details?["command"]?.value as? String).flatMap({ $0.isEmpty ? nil : $0 }) ?? latestToolCommands[toolCallId] ?? ""
          let exitCode = (result.details?["exitCode"]?.value as? Int) ?? (isError ? 1 : 0)
          updateMessage(at: currentIndex) {
            let run = TerminalRun(command: command, output: result.textOutput, exitCode: exitCode)
            $0.terminal.append(run)
            // Best practice: bash terminal (command+output) is single source of truth — remove duplicate Tool chip.
            $0.tools.removeAll { $0.callId == toolCallId && $0.name.lowercased().contains("bash") }
            if let chipIndex = $0.segments.firstIndex(where: { segment in
              guard case .tool(let tool) = segment else { return false }
              return tool.callId == toolCallId
            }) {
              $0.segments.remove(at: chipIndex)
              $0.segments.insert(.terminal(run), at: chipIndex)
            } else {
              // Fallback: remove any matching tool segment and append terminal
              $0.segments.removeAll { seg in
                if case .tool(let t) = seg { return t.callId == toolCallId }
                return false
              }
              $0.segments.append(.terminal(run))
            }
          }
        }

      case .messageEnd(let message):
        updateThinkingSeconds()
        if message.role == "assistant" {
          finalize(message: message, at: currentIndex)
          finalizedCurrentTurn = true
        }

      case .agentEnd(let messages):
        updateThinkingSeconds()
        if !finalizedCurrentTurn, let last = messages.last(where: { $0.role == "assistant" }) {
          finalize(message: last, at: currentIndex)
        } else {
          updateMessage(at: currentIndex) { $0.isStreaming = false }
        }

      case .autoRetryStart(let attempt, _, _, let errorMessage):
        updateMessage(at: currentIndex) {
          if $0.thinking == nil {
            $0.thinking = Thinking(summary: "", truncated: "", full: "", seconds: 0)
          }
          $0.thinking?.summary += "\n[Retry \(attempt): \(errorMessage)]"
        }

      case .extensionError(_, _, let error):
        if stopRequested && isAbortError(error) {
          break
        }
        updateMessage(at: currentIndex) {
          $0.error = error
        }

      default:
        break
      }
    }

    // If session switched during stream, discard the orphaned assistant message(s).
    if let expectedSessionId, self.cacheSessionId != expectedSessionId {
      // Remove any assistant messages appended for the stale stream that are still streaming/empty.
      // The messages were appended at messageIndex; if they are empty, remove them to avoid polluting new session.
      await MainActor.run {
        // Remove trailing empty streaming messages for the stale session.
        while let last = self.messages.last, last.isStreaming && last.text.isEmpty && last.tools.isEmpty {
          self.messages.removeLast()
        }
        // Also handle the original messageIndex if it’s still streaming empty.
        if self.messages.indices.contains(messageIndex), self.messages[messageIndex].isStreaming, self.messages[messageIndex].text.isEmpty {
          self.messages.remove(at: messageIndex)
        }
        self.generatingMessageId = nil
        self.isResponding = false
      }
      return
    }
    self.generatingMessageId = nil
    guard self.messages.indices.contains(currentIndex) else {
      return
    }
    if self.messages[currentIndex].isStreaming {
      updateMessage(at: currentIndex) { $0.isStreaming = false }
    }
    await syncStateFromServer()
    // First turn of a new chat: adopt server session so sidebar updates.
    // Only adopt if we were previously unselected (new chat draft).
    if expectedSessionId == nil {
      do {
        let state = try await rpcClient.getState()
        if let newId = state.data?.sessionId, !newId.isEmpty {
          // Don't set cache here — let SidebarStore adopt atomically via loadSessions
          await MainActor.run { self.onNewSessionAdopted?(newId) }
        }
      } catch {}
    }
    // Only persist if still the same session.
    if let expectedSessionId, self.cacheSessionId != expectedSessionId { return }
    persistChatCache()
    // The server generates the session title asynchronously after a run;
    // refresh once more shortly after to pick it up.
    let persistSession = expectedSessionId ?? self.cacheSessionId
    Task { @MainActor [weak self] in
      try? await Task.sleep(for: .seconds(10))
      guard let self, self.cacheSessionId == persistSession else { return }
      await self.syncStateFromServer()
      self.persistChatCache()
    }
    processQueue()
  }

  private func updateMessage(at index: Int, _ update: (inout ChatMessage) -> Void) {
    guard self.messages.indices.contains(index) else {
      return
    }
    var message = self.messages[index]
    let oldText = message.text
    update(&message)
    self.messages[index] = message
    if message.text != oldText {
    } else {
    }
  }

  private func finalize(message: AgentMessage, at index: Int) {
    guard self.messages.indices.contains(index) else { return }

    let built = buildSegments(from: message.content)

    let tokenCount = message.usage?.totalTokens ?? ((message.usage?.input ?? 0) + (message.usage?.output ?? 0))
    let rawErrorText = message.errorMessage?.isEmpty == false ? message.errorMessage : nil
    let errorText: String? = {
      guard let rawErrorText else { return nil }
      if stopRequested && isAbortError(rawErrorText) {
        return nil
      }
      return rawErrorText
    }()
    updateMessage(at: index) { message in
      if let built {
        message.segments = built.segments
        message.text = built.text
        message.code = built.code
      }
      message.isStreaming = false
      message.tokens = tokenCount
      if let errorText {
        message.error = errorText
      }
    }
    self.usedTokens += tokenCount
  }

  /// Builds ordered render segments from message content blocks, extracting the
  /// first fenced code block into a dedicated code view. Returns nil when the
  /// content is missing, so callers keep whatever was accumulated while streaming.
  private func buildSegments(from content: AgentMessage.MessageContent?) -> (segments: [ChatMessage.Segment], text: String, code: (language: String, source: String)?)? {
    guard let content else { return nil }

    let blocks: [AgentMessage.ContentBlock]
    switch content {
    case .text(let string):
      blocks = [.text(string)]
    case .blocks(let contentBlocks):
      blocks = contentBlocks
    }

    var segments: [ChatMessage.Segment] = []
    var code: (language: String, source: String)? = nil
    for block in blocks {
      switch block {
      case .text(let rawText):
        var text = rawText
        if code == nil {
          let (stripped, found) = stripFirstCodeBlock(from: text)
          if let found {
            code = found
            text = stripped
          }
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
          segments.append(.text(text: trimmed))
        }
      case .toolCall(let call):
        let detail = formatToolDetail(name: call.name, arguments: call.arguments)
        segments.append(.tool(ToolUse(kind: toolKind(for: call.name), name: call.name, detail: detail, symbol: toolSymbol(for: call.name), callId: call.id)))
      case .thinking, .unknown:
        break
      }
    }

    let text = segments.compactMap { segment -> String? in
      guard case .text(_, let text) = segment else { return nil }
      return text
    }.joined(separator: "\n\n")

    return (segments, text, code)
  }

  private func stripFirstCodeBlock(from text: String) -> (text: String, code: (language: String, source: String)?) {
    guard let startRange = text.range(of: "```\\n?([^\\n]*)\\n", options: .regularExpression) else {
      return (text, nil)
    }
    let fence = String(text[startRange])
    let language = fence.trimmingCharacters(in: CharacterSet(charactersIn: "`\n"))
    let afterFence = text[startRange.upperBound...]
    guard let endRange = afterFence.range(of: "\n```") else { return (text, nil) }
    let source = String(afterFence[..<endRange.lowerBound])
    let code: (language: String, source: String) = (language.isEmpty ? "text" : language, source)
    let textBefore = String(text[..<startRange.lowerBound])
    let textAfter = String(afterFence[endRange.upperBound...])
    let remaining = textBefore + textAfter
    return (remaining, code)
  }

  private func toolKind(for name: String) -> ToolKind {
    if name.hasPrefix("mcp/") || name.lowercased().contains("mcp") { return .mcp }
    if name.hasPrefix("skill/") || name.lowercased().contains("skill") { return .skill }
    return .builtin
  }

  private func toolSymbol(for name: String) -> String {
    switch name.lowercased() {
    case let n where n.contains("search"): return "magnifyingglass"
    case let n where n.contains("edit") || n.contains("write"): return "pencil.line"
    case let n where n.contains("read"): return "doc.text"
    case let n where n.contains("bash") || n.contains("run"): return "terminal"
    case let n where n.contains("test"): return "checkmark.seal"
    default: return "gearshape.2"
    }
  }

  /// Prefer the primary value for single-arg tools (bash command, file path).
  /// Fall back to stable "key: value" lines for multi-arg calls.
  private func formatToolDetail(name: String, arguments: [String: AnyCodable]?) -> String {
    guard let arguments, !arguments.isEmpty else { return "" }

    let preferredKeys = preferredDetailKeys(for: name)
    for key in preferredKeys {
      if let raw = arguments[key]?.value {
        let text = stringValue(raw)
        if !text.isEmpty { return text }
      }
    }

    // Single argument — show value only
    if arguments.count == 1, let only = arguments.values.first {
      return stringValue(only.value)
    }

    return arguments
      .sorted { $0.key < $1.key }
      .map { "\($0.key): \(stringValue($0.value.value))" }
      .joined(separator: "\n")
  }

  private func preferredDetailKeys(for name: String) -> [String] {
    switch name.lowercased() {
    case let n where n.contains("bash") || n.contains("shell") || n.contains("run"):
      return ["command", "cmd", "script"]
    case let n where n.contains("read") || n.contains("write") || n.contains("edit"):
      return ["path", "file", "file_path", "filename"]
    case let n where n.contains("search") || n.contains("grep") || n.contains("find"):
      return ["query", "pattern", "path"]
    default:
      return ["command", "path", "file", "query"]
    }
  }

  private func stringValue(_ value: Any) -> String {
    switch value {
    case let s as String: return s
    case let n as NSNumber: return n.stringValue
    case let b as Bool: return b ? "true" : "false"
    case is NSNull: return ""
    default: return "\(value)"
    }
  }
}

@MainActor
@Observable
final class SidebarStore {
  var sessions: [SessionInfo] = []
  var selectedSessionId: String? = nil
  var activeChat: ChatStore
  var searchText = ""
  /// True while a background network revalidation is in flight.
  var isRefreshing = false

  private let rpcClient = PiRPCClient()

  /// - Parameter connectToServer: When `false`, skip RPC bootstrap (previews / offline mocks).
  init(connectToServer: Bool = true) {
    activeChat = ChatStore(connectToServer: connectToServer)
    activeChat.onNewSessionAdopted = { [weak self] newId in
      Task { @MainActor in
        await self?.adoptNewChatSession(newId)
      }
    }
    guard connectToServer else { return }
    hydrateFromCache()
    Task { @MainActor in
      await refreshFromServer()
    }
  }

  /// Adopt the server-assigned sessionId for the first turn of a previously
  /// unselected new chat, then refresh the sidebar list.
  private func adoptNewChatSession(_ sessionId: String) async {
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
  private func hydrateFromCache() {
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
  private func refreshFromServer() async {
    isRefreshing = true
    defer { isRefreshing = false }

    await loadSessions()
    await activeChat.loadAvailableModels()
    await activeChat.loadAvailableCommands()
    await syncActiveSession(clearBeforeLoad: false)
    persistPrefs()
  }

  private func persistPrefs() {
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

  private func sessionDay(_ session: SessionInfo) -> Date? {
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
    // Immediately clear sidebar selection so no existing session looks active.
    await MainActor.run {
      withAnimation(.snappy) {
        selectedSessionId = nil
        activeChat.cacheSessionId = nil
      }
      persistPrefs()
    }
    await activeChat.resetToSession(title: "New chat")

    do {
      _ = try await rpcClient.newSession()
      // Try to select the newly created session immediately so the first
      // prompt is guaranteed to route to the new session even if user
      // taps Send quickly. This also makes the empty "New chat" appear
      // in the sidebar right away (avoids "send to previous session" race).
      do {
        let state = try await rpcClient.getState()
        if let newId = state.data?.sessionId, !newId.isEmpty {
          await MainActor.run {
            selectedSessionId = newId
            activeChat.cacheSessionId = newId
            persistPrefs()
          }
          await loadSessions()
          // Keep selection even if list hasn't yet included the new file.
          if selectedSessionId != newId {
            await MainActor.run {
              selectedSessionId = newId
              activeChat.cacheSessionId = newId
              persistPrefs()
            }
          }
          return
        }
      } catch {}
      await loadSessions()
      // Fallback: stay unselected while composing; server already switched.
      await MainActor.run {
        selectedSessionId = nil
        activeChat.cacheSessionId = nil
        persistPrefs()
      }
    } catch {
      // UI already shows empty "New chat" with nothing selected.
    }
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
    activeChat = ChatStore(connectToServer: false)
    activeChat.onNewSessionAdopted = { [weak self] newId in
      Task { @MainActor in
        await self?.adoptNewChatSession(newId)
      }
    }
    PiCache.clearAll()
  }

  /// - Parameter clearBeforeLoad: When `true`, wipe the chat before fetching (legacy).
  ///   Launch refresh uses `false` so cached messages stay visible until RPC returns.
  private func syncActiveSession(clearBeforeLoad: Bool = true) async {
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
