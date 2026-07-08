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
  var model: AIModel = .fable
  var thinkingLevel: ThinkingLevel = .high
  var usedTokens: Int = 0
  var draft: String = ""
  var isResponding = false
  var chatTitle = "New chat"
  var editingMessageId: UUID? = nil
  var pastedItems: [PastedItem] = []
  var contextFiles: [ContextFile] = []
  var messageQueue: [String] = []

  var contextFraction: Double {
    min(1, Double(usedTokens) / Double(model.contextWindow))
  }

  var isStreaming: Bool { messages.contains { $0.isStreaming } }

  var queuedMessagesForDisplay: [QueuedMessage] {
    messageQueue.enumerated().reversed().map { QueuedMessage(id: $0.offset, text: $0.element) }
  }

  init() { AICodeChatMock.seed(into: self) }

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
      if let index = messages.firstIndex(where: { $0.id == id }) {
        messages[index].text = trimmed
      }
      withAnimation(.snappy) {
        editingMessageId = nil
        draft = ""
        pastedItems = []
        contextFiles = []
      }
      return
    }

    draft = ""
    pastedItems = []
    contextFiles = []

    if isResponding || isStreaming {
      withAnimation(.snappy) {
        messageQueue.append(trimmed)
      }
      return
    }

    sendNow(trimmed)
  }

  private func composeBody() -> String {
    let pastedBody = pastedItems.map(\.content).joined(separator: "\n\n")
    let fileBody = contextFiles.map { "File: \($0.name)\n\($0.content)" }.joined(separator: "\n\n")
    let attachmentsBody = [pastedBody, fileBody].filter { !$0.isEmpty }.joined(separator: "\n\n")
    return [draft, attachmentsBody].filter { !$0.isEmpty }.joined(separator: "\n\n")
  }

  private func sendNow(_ text: String) {
    if messages.isEmpty { chatTitle = String(text.prefix(34)) }

    withAnimation(.snappy) {
      messages.append(ChatMessage(role: .user, text: text, tokens: 180))
      usedTokens += 180
      isResponding = true
    }

    Task { @MainActor in
      await streamReply(for: text)
    }
  }

  private func processQueue() {
    guard !messageQueue.isEmpty, !isResponding, !isStreaming else { return }
    let next = messageQueue.removeFirst()
    sendNow(next)
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

    let userText = messages[assistantIndex - 1].text

    withAnimation(.snappy) {
      messages.removeSubrange(assistantIndex...)
      isResponding = true
    }

    Task { @MainActor in
      await streamReply(for: userText)
    }
  }

  func retryWithDifferentSettings(from assistantMessageId: UUID) {
    guard let assistantIndex = messages.firstIndex(where: { $0.id == assistantMessageId }),
          assistantIndex > 0,
          messages[assistantIndex - 1].role == .user else { return }

    let userMessage = messages[assistantIndex - 1]
    startEditing(message: userMessage)
  }

  private func streamReply(for userText: String) async {
    try? await Task.sleep(for: .seconds(0.6))

    let reply = AICodeChatMock.cannedReply(level: self.thinkingLevel)
    let messageIndex = self.messages.count

    await MainActor.run {
      withAnimation(.snappy) {
        self.messages.append(ChatMessage(role: .assistant, text: "", tokens: 0, isStreaming: true))
        self.isResponding = false
      }
    }

    if let thinking = reply.thinking {
      guard self.messages.indices.contains(messageIndex) else { return }
      await MainActor.run {
        self.messages[messageIndex].thinking = Thinking(
          summary: "",
          truncated: thinking.truncated,
          full: thinking.full,
          seconds: thinking.seconds
        )
      }
      await Self.stream(text: thinking.summary) { partial in
        if self.messages.indices.contains(messageIndex) {
          self.messages[messageIndex].thinking?.summary = partial
        }
      }
      try? await Task.sleep(for: .milliseconds(300))
    }

    await Self.stream(text: reply.text) { partial in
      if self.messages.indices.contains(messageIndex) {
        self.messages[messageIndex].text = partial
      }
    }

    guard self.messages.indices.contains(messageIndex) else { return }
    await MainActor.run {
      withAnimation(.snappy) {
        self.messages[messageIndex].code = reply.code
        self.messages[messageIndex].terminal = reply.terminal
        self.messages[messageIndex].tokens = reply.tokens
        self.messages[messageIndex].isStreaming = false
        self.usedTokens += reply.tokens
      }
    }

    processQueue()
  }

  private static func stream(text: String, update: @escaping (String) -> Void) async {
    var partial = ""
    for char in text {
      partial.append(char)
      await MainActor.run { [partial] in
        update(partial)
      }
      try? await Task.sleep(for: .milliseconds(12))
    }
  }
}

@MainActor
@Observable
final class SidebarStore {
  var chats: [ChatStore] = []
  var selectedChatId: UUID? = nil
  var searchText = ""

  init() {
    chats = AICodeChatMock.chatTitles.map { title in
      let chat = ChatStore()
      chat.chatTitle = title
      return chat
    }
    selectedChatId = chats.first?.id
  }

  var filteredChats: [ChatStore] {
    let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if query.isEmpty { return chats }
    return chats.filter { $0.chatTitle.lowercased().contains(query) }
  }

  func newChat() {
    let chat = ChatStore()
    withAnimation(.snappy) {
      chats.append(chat)
      selectedChatId = chat.id
    }
  }

  func select(chatId: UUID) {
    withAnimation(.snappy) {
      selectedChatId = chatId
    }
  }

  func delete(chatId: UUID) {
    withAnimation(.snappy) {
      chats.removeAll { $0.id == chatId }
      if selectedChatId == chatId {
        selectedChatId = chats.last?.id
      }
    }
  }
}
