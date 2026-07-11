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

  private let rpcClient = PiRPCClient()

  var contextFraction: Double {
    min(1, Double(usedTokens) / Double(selectedModel?.contextWindow ?? 200_000))
  }

  var isStreaming: Bool { messages.contains { $0.isStreaming } }
  var generatingMessageId: UUID? = nil

  var queuedMessagesForDisplay: [QueuedMessage] {
    messageQueue.enumerated().reversed().map { QueuedMessage(id: $0.offset, text: $0.element) }
  }

  init() {
    Task { @MainActor in
      await loadAvailableModels()
    }
  }

  func loadAvailableModels() async {
    do {
      let response = try await rpcClient.getAvailableModels()
      if let models = response.data?.models, !models.isEmpty {
        withAnimation(.snappy) {
          self.availableModels = models
          if self.selectedModel == nil {
            self.selectedModel = models.first
          }
        }
      }
    } catch {
      // Server may not expose this command; leave the list empty.
    }
  }

  func selectModel(_ model: AgentModel) async {
    do {
      _ = try await rpcClient.setModel(provider: model.provider ?? "", modelId: model.id)
      await MainActor.run {
        withAnimation(.snappy) { self.selectedModel = model }
      }
      await syncStateFromServer()
    } catch {
      await MainActor.run {
        withAnimation(.snappy) { self.selectedModel = model }
      }
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
    if let model = state.model {
      self.selectedModel = model
    }
    if let levelString = state.thinkingLevel {
      self.thinkingLevel = ThinkingLevel(id: levelString)
    }
    self.supportedThinkingLevels = self.buildSupportedThinkingLevels(from: state.model?.thinkingLevelMap)
  }

  private func syncStateFromServer() async {
    do {
      let state = try await rpcClient.getState()
      await MainActor.run {
        withAnimation(.snappy) {
          if let stateData = state.data {
            self.apply(state: stateData)
          }
        }
      }
    } catch {
      // Keep existing levels if the server is unreachable.
    }
  }

  func loadMessages() async {
    do {
      let response = try await rpcClient.getEntries()
      guard let entries = response.data?.entries else { return }

      // Walk entries in order so toolResult messages can be attached to the
      // preceding assistant tool call (they are stored as separate entries).
      var chatMessages: [ChatMessage] = []
      for entry in entries {
        guard entry.type == "message", let agentMessage = entry.message else { continue }
        guard let role = agentMessage.role else { continue }
        let text = agentMessage.content?.textBlocks().joined(separator: "\n\n") ?? ""

        if role == "user" {
          chatMessages.append(ChatMessage(entryId: entry.id, role: .user, text: text, tokens: 0))
        } else if role == "assistant" {
          var message = ChatMessage(entryId: entry.id, role: .assistant, text: text, tokens: 0)
          self.populate(message: &message, from: agentMessage)
          chatMessages.append(message)
        } else if role == "toolResult" {
          let output = text
          let toolCallId = agentMessage.toolCallId
          let toolName = agentMessage.toolName ?? "tool"
          let isError = agentMessage.isError ?? false
          // Attach to the most recent assistant message that owns this tool call.
          if let idx = chatMessages.lastIndex(where: { $0.role == .assistant }) {
            attachToolOutput(
              to: &chatMessages[idx],
              toolCallId: toolCallId,
              toolName: toolName,
              output: output,
              isError: isError
            )
          }
        }
      }

      let state = try await rpcClient.getState()
      await MainActor.run {
        withAnimation(.snappy) {
          self.messages = chatMessages
          self.usedTokens = chatMessages.reduce(0) { $0 + $1.tokens }
          if let stateData = state.data {
            self.apply(state: stateData)
          }
        }
      }
    } catch {
      // Leave messages empty if the server is unreachable.
    }
  }

  private func populate(message: inout ChatMessage, from agentMessage: AgentMessage) {
    if let usage = agentMessage.usage {
      message.tokens = usage.totalTokens ?? ((usage.input ?? 0) + (usage.output ?? 0))
    }

    if let thinkingText = agentMessage.content?.thinkingBlocks().joined(separator: "\n\n"), !thinkingText.isEmpty {
      message.thinking = Thinking(summary: thinkingText, truncated: thinkingText, full: thinkingText, seconds: 0)
    }

    let toolCalls = agentMessage.content?.toolCalls() ?? []
    message.tools = toolCalls.map { call in
      let detail = formatToolDetail(name: call.name, arguments: call.arguments)
      return ToolUse(
        toolCallId: call.id,
        kind: toolKind(for: call.name),
        name: call.name,
        detail: detail,
        symbol: toolSymbol(for: call.name)
      )
    }

    let (textWithoutCode, code) = stripFirstCodeBlock(from: message.text)
    message.code = code
    message.text = textWithoutCode.trimmingCharacters(in: .whitespacesAndNewlines)
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

  private func processQueue() {
    guard !messageQueue.isEmpty, !isResponding, !isStreaming else { return }
    let next = messageQueue.removeFirst()
    sendNow(next, repo: includedRepo)
  }

  func removeQueuedMessage(at index: Int) {
    guard messageQueue.indices.contains(index) else { return }
    _ = withAnimation(.snappy) {
      messageQueue.remove(at: index)
    }
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
    let messageIndex = self.messages.count
    print("[ChatStore] streamReply start index=\(messageIndex)")

    withAnimation(.snappy) {
      self.messages.append(ChatMessage(role: .assistant, text: "", tokens: 0, isStreaming: true))
      self.isResponding = false
    }
    print("[ChatStore] appended streaming assistant message at index=\(messageIndex)")
    self.generatingMessageId = self.messages[messageIndex].id

    do {
      try await rpcClient.setThinkingLevel(thinkingLevel)
    } catch {
      print("[ChatStore] setThinkingLevel failed: \(error.localizedDescription)")
    }

    let userMessageIndex = messageIndex - 1
    await consumeStreamEvents(
      rpcClient.streamEvents(
        forPrompt: userText,
        repo: repo?.url,
        onEntryId: { [weak self] entryId in
          guard let self, let entryId = entryId else { return }
          print("[ChatStore] prompt entryId captured: \(entryId)")
          self.updateMessage(at: userMessageIndex) { $0.entryId = entryId }
        }
      ),
      at: messageIndex
    )
  }

  private func streamRerun(message: String? = nil, entryId: String? = nil, userMessageIndex: Int? = nil) async {
    let messageIndex = self.messages.count
    print("[ChatStore] streamRerun start index=\(messageIndex)")

    withAnimation(.snappy) {
      self.messages.append(ChatMessage(role: .assistant, text: "", tokens: 0, isStreaming: true))
      self.isResponding = false
    }
    print("[ChatStore] appended streaming assistant message at index=\(messageIndex)")
    self.generatingMessageId = self.messages[messageIndex].id

    do {
      try await rpcClient.setThinkingLevel(thinkingLevel)
    } catch {
      print("[ChatStore] setThinkingLevel failed: \(error.localizedDescription)")
    }

    await consumeStreamEvents(
      rpcClient.streamRerunEvents(
        message: message,
        entryId: entryId,
        onEntryId: { [weak self] returnedEntryId in
          guard let self, let userMessageIndex = userMessageIndex, let returnedEntryId = returnedEntryId else { return }
          print("[ChatStore] rerun entryId captured: \(returnedEntryId)")
          self.updateMessage(at: userMessageIndex) { $0.entryId = returnedEntryId }
        }
      ),
      at: messageIndex
    )
  }

  private func consumeStreamEvents(_ events: AsyncStream<AgentEvent>, at messageIndex: Int) async {
    var latestToolNames: [String: String] = [:]
    var thinkingStartTime: Date?

    func updateThinkingSeconds() {
      guard let start = thinkingStartTime else { return }
      let elapsed = Date().timeIntervalSince(start)
      updateMessage(at: messageIndex) {
        if $0.thinking == nil {
          $0.thinking = Thinking(summary: "", truncated: "", full: "", seconds: 0)
        }
        $0.thinking?.seconds = elapsed
      }
    }

    print("[ChatStore] entering event loop")
    for await event in events {
      print("[ChatStore] received event: \(event.debugName)")
      guard self.messages.indices.contains(messageIndex) else {
        print("[ChatStore] message index \(messageIndex) out of range, breaking")
        break
      }

      switch event {
      case .agentStart:
        updateMessage(at: messageIndex) { $0.isStreaming = true }

      case .messageStart:
        updateMessage(at: messageIndex) { $0.isStreaming = true }

      case .messageUpdate(_, let delta):
        switch delta {
        case .textDelta(_, let text):
          print("[ChatStore] textDelta: '\(text.prefix(80))'")
          updateMessage(at: messageIndex) { $0.text += text }
        case .thinkingStart:
          thinkingStartTime = Date()
          updateMessage(at: messageIndex) {
            if $0.thinking == nil {
              $0.thinking = Thinking(summary: "", truncated: "", full: "", seconds: 0)
            }
          }
        case .thinkingDelta(_, let text):
          updateMessage(at: messageIndex) {
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
          updateMessage(at: messageIndex) {
            $0.tools.append(
              ToolUse(
                toolCallId: call.id,
                kind: toolKind(for: call.name),
                name: call.name,
                detail: detail,
                symbol: toolSymbol(for: call.name)
              )
            )
          }
          if let id = call.id { latestToolNames[id] = call.name }
        default:
          break
        }

      case .toolExecutionStart(let toolCallId, let toolName, let args):
        if !toolCallId.isEmpty { latestToolNames[toolCallId] = toolName }
        let detail = formatToolDetail(name: toolName, arguments: stringAnyCodableArgs(args))
        updateMessage(at: messageIndex) {
          // Ensure a chip exists even if toolcall_end was missed or raced.
          if let idx = $0.tools.lastIndex(where: { $0.toolCallId == toolCallId }) {
            if $0.tools[idx].detail.isEmpty, !detail.isEmpty {
              var tools = $0.tools
              tools[idx] = ToolUse(
                toolCallId: toolCallId,
                kind: toolKind(for: toolName),
                name: toolName,
                detail: detail,
                symbol: toolSymbol(for: toolName),
                output: tools[idx].output,
                exitCode: tools[idx].exitCode
              )
              $0.tools = tools
            }
            return
          }
          if let idx = $0.tools.lastIndex(where: { $0.name == toolName && $0.output == nil }) {
            $0.tools[idx].toolCallId = toolCallId.isEmpty ? $0.tools[idx].toolCallId : toolCallId
            return
          }
          $0.tools.append(
            ToolUse(
              toolCallId: toolCallId.isEmpty ? nil : toolCallId,
              kind: toolKind(for: toolName),
              name: toolName,
              detail: detail,
              symbol: toolSymbol(for: toolName)
            )
          )
        }

      case .toolExecutionUpdate(let toolCallId, let partialResult):
        let name = latestToolNames[toolCallId] ?? "tool"
        let output = toolResultText(partialResult)
        guard !output.isEmpty else { break }
        updateMessage(at: messageIndex) {
          attachToolOutput(to: &$0, toolCallId: toolCallId, toolName: name, output: output, isError: false, exitCode: nil)
        }

      case .toolExecutionEnd(let toolCallId, let toolName, let result, let isError):
        let name = latestToolNames[toolCallId] ?? toolName
        let exitCode = intValue(result.details?["exitCode"]?.value) ?? (isError ? 1 : 0)
        let output = toolResultText(result)
        print("[ChatStore] toolExecutionEnd id=\(toolCallId) name=\(name) outputChars=\(output.count) isError=\(isError)")
        updateMessage(at: messageIndex) {
          attachToolOutput(
            to: &$0,
            toolCallId: toolCallId,
            toolName: name,
            output: output,
            isError: isError,
            exitCode: exitCode
          )
          if name == "bash" || name.lowercased().contains("bash") {
            let command = (result.details?["command"]?.value as? String)
              ?? $0.tools.last(where: { $0.toolCallId == toolCallId })?.detail
              ?? ""
            $0.terminal.append(TerminalRun(command: command, output: output, exitCode: exitCode))
          }
        }

      case .messageEnd(let message):
        print("[ChatStore] messageEnd role=\(message.role ?? "nil")")
        updateThinkingSeconds()
        if message.role == "toolResult" {
          // Backup path: server also emits tool results as standalone messages.
          let output = message.content?.textBlocks().joined(separator: "\n") ?? ""
          let toolCallId = message.toolCallId ?? ""
          let name = message.toolName ?? latestToolNames[toolCallId] ?? "tool"
          let isError = message.isError ?? false
          print("[ChatStore] toolResult messageEnd id=\(toolCallId) outputChars=\(output.count)")
          updateMessage(at: messageIndex) {
            attachToolOutput(
              to: &$0,
              toolCallId: toolCallId.isEmpty ? nil : toolCallId,
              toolName: name,
              output: output,
              isError: isError,
              exitCode: isError ? 1 : 0
            )
          }
        } else if message.role == "assistant" {
          finalize(message: message, at: messageIndex)
        }

      case .turnEnd(_, let toolResults):
        // turn_end.toolResults are full toolResult payloads (with content text).
        for result in toolResults {
          let output = toolResultText(result)
          guard !output.isEmpty else { continue }
          updateMessage(at: messageIndex) {
            // Prefer last bash/tool without output; turn_end results lack toolCallId on AgentToolResult.
            attachToolOutput(
              to: &$0,
              toolCallId: nil,
              toolName: $0.tools.last(where: { $0.output == nil })?.name ?? "bash",
              output: output,
              isError: false,
              exitCode: 0
            )
          }
        }

      case .agentEnd(let messages):
        print("[ChatStore] agentEnd messages.count=\(messages.count)")
        updateThinkingSeconds()
        if let last = messages.last(where: { $0.role == "assistant" }) {
          finalize(message: last, at: messageIndex)
        } else {
          updateMessage(at: messageIndex) { $0.isStreaming = false }
        }

      case .autoRetryStart(let attempt, _, _, let errorMessage):
        updateMessage(at: messageIndex) {
          if $0.thinking == nil {
            $0.thinking = Thinking(summary: "", truncated: "", full: "", seconds: 0)
          }
          $0.thinking?.summary += "\n[Retry \(attempt): \(errorMessage)]"
        }

      case .extensionError(_, _, let error):
        updateMessage(at: messageIndex) {
          if $0.text.isEmpty {
            $0.text = "⚠️ \(error)"
          }
        }

      default:
        break
      }
    }

    print("[ChatStore] event loop ended")
    self.generatingMessageId = nil
    guard self.messages.indices.contains(messageIndex) else {
      print("[ChatStore] final check: index \(messageIndex) out of range")
      return
    }
    if self.messages[messageIndex].isStreaming {
      print("[ChatStore] forcing isStreaming=false at end")
      updateMessage(at: messageIndex) { $0.isStreaming = false }
    }
    print("[ChatStore] final message text='\(self.messages[messageIndex].text.prefix(80))' streaming=\(self.messages[messageIndex].isStreaming)")
    processQueue()
  }

  private func updateMessage(at index: Int, _ update: (inout ChatMessage) -> Void) {
    guard self.messages.indices.contains(index) else {
      print("[ChatStore] updateMessage index \(index) out of range")
      return
    }
    var message = self.messages[index]
    let oldText = message.text
    update(&message)
    self.messages[index] = message
    if message.text != oldText {
      print("[ChatStore] updateMessage index=\(index) text changed '\(oldText.prefix(40))' -> '\(message.text.prefix(40))'")
    } else {
      print("[ChatStore] updateMessage index=\(index) (no text change)")
    }
  }

  private func finalize(message: AgentMessage, at index: Int) {
    guard self.messages.indices.contains(index) else { return }

    let assistantText = message.content?.textBlocks().joined(separator: "\n\n") ?? self.messages[index].text
    let (textWithoutCode, code) = stripFirstCodeBlock(from: assistantText)

    let tokenCount = message.usage?.totalTokens ?? ((message.usage?.input ?? 0) + (message.usage?.output ?? 0))
    updateMessage(at: index) { message in
      message.text = textWithoutCode.trimmingCharacters(in: .whitespacesAndNewlines)
      message.code = code
      message.isStreaming = false
      message.tokens = tokenCount
    }
    self.usedTokens += tokenCount
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

  /// Attach stdout/result text onto the matching tool chip, replacing the tools
  /// array so Observation/SwiftUI always picks up the nested change.
  private func attachToolOutput(
    to message: inout ChatMessage,
    toolCallId: String?,
    toolName: String,
    output: String,
    isError: Bool,
    exitCode: Int? = nil
  ) {
    let resolvedExit = exitCode ?? (isError ? 1 : 0)
    var tools = message.tools

    let index: Int? = {
      if let toolCallId, !toolCallId.isEmpty,
         let idx = tools.lastIndex(where: { $0.toolCallId == toolCallId }) {
        return idx
      }
      if let idx = tools.lastIndex(where: { $0.name == toolName && ($0.output == nil || $0.output?.isEmpty == true) }) {
        return idx
      }
      if let idx = tools.lastIndex(where: { $0.name == toolName }) {
        return idx
      }
      return tools.lastIndex(where: { $0.output == nil || $0.output?.isEmpty == true })
    }()

    if let index {
      tools[index].toolCallId = tools[index].toolCallId ?? toolCallId
      tools[index].output = output
      tools[index].exitCode = resolvedExit
    } else {
      tools.append(
        ToolUse(
          toolCallId: toolCallId,
          kind: toolKind(for: toolName),
          name: toolName,
          detail: "",
          symbol: toolSymbol(for: toolName),
          output: output,
          exitCode: resolvedExit
        )
      )
    }
    message.tools = tools
  }

  private func toolResultText(_ result: AgentToolResult) -> String {
    let fromContent = result.textOutput.trimmingCharacters(in: .whitespacesAndNewlines)
    if !fromContent.isEmpty { return result.textOutput }
    if let s = result.details?["output"]?.value as? String, !s.isEmpty { return s }
    if let s = result.details?["stdout"]?.value as? String, !s.isEmpty { return s }
    if let s = result.details?["text"]?.value as? String, !s.isEmpty { return s }
    return result.textOutput
  }

  private func stringAnyCodableArgs(_ args: [String: Any]) -> [String: AnyCodable] {
    // Wrap raw SSE args so formatToolDetail can read preferred keys.
    Dictionary(uniqueKeysWithValues: args.map { key, value in
      (key, AnyCodable(value: value))
    })
  }

  private func intValue(_ value: Any?) -> Int? {
    switch value {
    case let i as Int: return i
    case let n as NSNumber: return n.intValue
    case let s as String: return Int(s)
    default: return nil
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
  var activeChat = ChatStore()
  var searchText = ""

  private let rpcClient = PiRPCClient()

  init() {
    Task { @MainActor in
      await loadSessions()
      await syncActiveSession()
    }
  }

  var filteredSessions: [SessionInfo] {
    let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if query.isEmpty { return sessions }
    return sessions.filter { sessionTitle($0).lowercased().contains(query) }
  }

  func sessionTitle(_ session: SessionInfo) -> String {
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
    do {
      let sessions = try await rpcClient.listSessions()
      await MainActor.run {
        withAnimation(.snappy) {
          self.sessions = sessions.sorted { $0.modified > $1.modified }
          if self.selectedSessionId == nil, let first = sessions.first {
            self.selectedSessionId = first.id
          }
        }
      }
    } catch {
      // Leave the list empty if the server is unreachable.
    }
  }

  func select(session: SessionInfo) async {
    guard session.id != selectedSessionId else { return }

    await MainActor.run {
      withAnimation(.snappy) { selectedSessionId = session.id }
    }

    do {
      _ = try await rpcClient.switchSession(path: session.path)
      await activeChat.resetToSession(title: sessionTitle(session))
      await activeChat.loadMessages()
    } catch {
      await activeChat.resetToSession(title: sessionTitle(session))
    }
  }

  func newChat() async {
    do {
      _ = try await rpcClient.newSession()
      await activeChat.resetToSession(title: "New chat")
      await loadSessions()
      await MainActor.run {
        withAnimation(.snappy) { selectedSessionId = sessions.first?.id }
      }
    } catch {
      await activeChat.resetToSession(title: "New chat")
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
    }
    if wasSelected, let next = sessions.first {
      await select(session: next)
    }
  }

  func logout() {
    sessions.removeAll()
    selectedSessionId = nil
    searchText = ""
    activeChat = ChatStore()
  }

  private func syncActiveSession() async {
    guard let session = sessions.first(where: { $0.id == selectedSessionId }) else { return }
    await activeChat.resetToSession(title: sessionTitle(session))
    await activeChat.loadMessages()
  }
}
