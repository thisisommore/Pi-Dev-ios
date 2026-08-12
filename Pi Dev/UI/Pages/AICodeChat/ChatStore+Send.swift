//
//  ChatStore+Send.swift
//  Pi Dev
//

import Observation
import SwiftUI

extension ChatStore {
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

  func composeBody() -> String {
    let pastedBody = pastedItems.map(\.content).joined(separator: "\n\n")
    let fileBody = contextFiles.map { "File: \($0.name)\n\($0.content)" }.joined(separator: "\n\n")
    let attachmentsBody = [pastedBody, fileBody].filter { !$0.isEmpty }.joined(separator: "\n\n")
    return [draft, attachmentsBody].filter { !$0.isEmpty }.joined(separator: "\n\n")
  }

  func sendNow(_ text: String, repo: IncludedRepo? = nil) {
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
        // Local stop already applied; abort is best-effort.
      }
      await self.syncStateFromServer()
      await MainActor.run {
        self.persistChatCache()
      }
    }
  }

  func isAbortError(_ text: String?) -> Bool {
    guard let text else { return false }
    return text.lowercased().contains("abort")
  }

  func processQueue() {
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

}

