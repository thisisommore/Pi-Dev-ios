//
//  ChatStore+Commands.swift
//  Pi Dev
//

import Observation
import SwiftUI

extension ChatStore {
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
        workingDir = nil
        messageQueue = []
        expandedToolGroups = []
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
      chatTitle = oldTitle
    }
  }

}

