//
//  AICodeChat.page+Controller.swift
//  Pi Dev
//

import Observation
import SwiftUI
import Combine

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
  /// Called after any prompt stream completes to refresh sidebar via RPC.
  /// SidebarStore sets this to trigger loadSessions() on the main actor.
  var onStreamCompleted: (() async -> Void)?
  /// Called as soon as the first token arrives for a new-chat draft, so the
  /// sidebar can appear via RPC without waiting for the full stream.
  var onFirstTokenForNewChat: (() async -> Void)?
  /// Called when a new-chat draft needs a server session created atomically
  /// before the first prompt. SidebarStore creates the session via RPC and
  /// returns the new sessionId. This is the only place new_session is issued
  /// for a draft, eliminating the newChat/prompt race.
  var createServerSessionForDraft: (() async -> String?)?

  @ObservationIgnored
  let rpcClient: any PiRPCP

  var contextFraction: Double {
    min(1, Double(usedTokens) / Double(selectedModel?.contextWindow ?? 200_000))
  }

  var isStreaming: Bool { messages.contains { $0.isStreaming } }
  var generatingMessageId: UUID? = nil
  var isGenerating: Bool { isResponding || isStreaming }
  var stopRequested = false

  /// Tool disclosure groups the user has opened. Used so the collection view
  /// can remasure cell height when expand/collapse changes.
  var expandedToolGroups: Set<UUID> = []

  // Stable UUID per queue entry — avoids ForEach diff glitches when removing by offset.
  var queuedMessageIDs: [UUID] = []

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
  init(connectToServer: Bool = true, rpcClient: any PiRPCP = PiRPCClient()) {
    self.rpcClient = rpcClient
    guard connectToServer else { return }
    // Models hydrate via SidebarStore.bootstrap; still refresh in background.
    Task { @MainActor in
      await self.loadAvailableModels()
      await self.loadAvailableCommands()
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
    expandedToolGroups = []

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

  func isToolGroupExpanded(_ id: UUID) -> Bool {
    self.expandedToolGroups.contains(id)
  }

  func setToolGroup(_ id: UUID, expanded: Bool) {
    if expanded {
      self.expandedToolGroups.insert(id)
    } else {
      self.expandedToolGroups.remove(id)
    }
  }
}

