//
//  ChatStore+Stream.swift
//  Pi Dev
//

import Observation
import SwiftUI

extension ChatStore {
  func streamReply(for userText: String, repo: IncludedRepo? = nil) async {
    if stopRequested {
      stopRequested = false
      isResponding = false
      generatingMessageId = nil
      return
    }
    // If this is the first message of a new-chat draft (no session yet),
    // create the server session atomically before prompting. This is the
    // only place a draft creates a session, so Send cannot race newChat.
    var streamSessionId = self.cacheSessionId
    let promptDir = workingDir
    if streamSessionId == nil, promptDir == nil, let create = createServerSessionForDraft {
      if let newId = await create() {
        streamSessionId = newId
        // create() already set cacheSessionId and selectedSessionId via
        // SidebarStore, but ensure local cache is in sync.
        self.cacheSessionId = newId
      } else {
        self.isResponding = false
        self.generatingMessageId = nil
        return
      }
    }
    let messageIndex = self.messages.count

    withAnimation(.snappy) {
      self.messages.append(ChatMessage(role: .assistant, text: "", tokens: 0, isStreaming: true))
      self.isResponding = false
    }
    self.generatingMessageId = self.messages[messageIndex].id

    do {
      try await rpcClient.setThinkingLevel(thinkingLevel)
    } catch {
      // Prompt can proceed with the last known thinking level.
    }

    let userMessageIndex = messageIndex - 1
    await consumeStreamEvents(
      rpcClient.streamEvents(
        forPrompt: userText,
        repo: repo?.url,
        dir: promptDir,
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
    if promptDir != nil {
      workingDir = nil
    }
  }

  func streamRerun(message: String? = nil, entryId: String? = nil, userMessageIndex: Int? = nil) async {
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
      // Prompt can proceed with the last known thinking level.
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

  func consumeStreamEvents(_ events: AsyncStream<AgentEvent>, at messageIndex: Int, expectedSessionId: String? = nil) async {
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
    if expectedSessionId == nil {
      do {
        let state = try await rpcClient.getState()
        if let newId = state.data?.sessionId, !newId.isEmpty {
          await MainActor.run { self.onNewSessionAdopted?(newId) }
        }
      } catch {}
    }
    if let onStreamCompleted {
      await onStreamCompleted()
    }
    if let expectedSessionId, self.cacheSessionId != expectedSessionId { return }
    persistChatCache()
    processQueue()
  }

  func updateMessage(at index: Int, _ update: (inout ChatMessage) -> Void) {
    guard self.messages.indices.contains(index) else {
      return
    }
    var message = self.messages[index]
    update(&message)
    self.messages[index] = message
  }

  func finalize(message: AgentMessage, at index: Int) {
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
}

