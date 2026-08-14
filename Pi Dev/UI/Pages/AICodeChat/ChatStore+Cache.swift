//
//  ChatStore+Cache.swift
//  Pi Dev
//

import Observation
import SwiftUI

extension ChatStore {
  func buildSupportedThinkingLevels(from map: [String: String?]?) -> [ThinkingLevel] {
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

  func apply(state: AgentState) {
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
      onDisplayTitleChanged?(name, true)
    }
    let levels = self.buildSupportedThinkingLevels(from: state.model?.thinkingLevelMap)
    if supportedThinkingLevels.map(\.id) != levels.map(\.id) {
      self.supportedThinkingLevels = levels
    }
  }

  func syncStateFromServer() async {
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

  func populate(message: inout ChatMessage, from agentMessage: AgentMessage, toolResults: [String: (output: String, isError: Bool)] = [:]) {
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
      message.code = nil
    } else {
      if !terminalRuns.isEmpty {
        message.segments = terminalRuns.map { .terminal($0) }
      }
    }
  }
}

