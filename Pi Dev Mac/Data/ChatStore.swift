//
//  ChatStore.swift
//  Pi Dev Mac
//

import Foundation
import Observation

@Observable
@MainActor
final class ChatStore {
    var sessions: [ChatSession]
    var selectedSessionID: ChatSession.ID?
    var searchText: String = ""
    var draft: String = ""
    var selectedModel: AIModelOption
    var selectedThinkingLevel: ThinkingLevel
    var isComposerFocused: Bool = false
    var isChangesSidebarVisible: Bool = false
    var selectedChangeFileID: FileChange.ID? = nil
    var showFolderPicker: Bool = false
    var usedTokens: Int = 46_800
    var contextWindow: Int = 200_000
    var expandedToolGroups: Set<UUID> = []

    var contextFraction: Double {
        guard contextWindow > 0 else { return 0 }
        return min(1, Double(usedTokens) / Double(contextWindow))
    }

    init(sessions: [ChatSession] = MockData.sessions) {
        self.sessions = sessions
        self.selectedModel = AIModelOption.catalog[0]
        self.selectedThinkingLevel = .medium
        self.selectedSessionID = sessions.first?.id
    }

    // MARK: - Derived

    var selectedSession: ChatSession? {
        guard let selectedSessionID else { return nil }
        return sessions.first { $0.id == selectedSessionID }
    }

    var selectedFileChange: FileChange? {
        guard let selectedChangeFileID,
              let session = selectedSession else { return nil }
        return session.fileChanges.first { $0.id == selectedChangeFileID }
    }

    var filteredSessions: [ChatSession] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = sessions.sorted { $0.updatedAt > $1.updatedAt }
        guard !query.isEmpty else { return base }
        return base.filter {
            $0.title.localizedCaseInsensitiveContains(query)
                || $0.preview.localizedCaseInsensitiveContains(query)
                || ($0.projectName?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    var sessionsByProject: [(project: String, sessions: [ChatSession])] {
        let grouped = Dictionary(grouping: filteredSessions) { $0.projectName ?? "Other" }
        return grouped
            .map { (project: $0.key, sessions: $0.value.sorted { $0.updatedAt > $1.updatedAt }) }
            .sorted { $0.project.localizedCaseInsensitiveCompare($1.project) == .orderedAscending }
    }

    // MARK: - Actions

    func select(_ session: ChatSession) {
        selectedSessionID = session.id
        draft = ""
        selectedChangeFileID = nil
    }

    func newChat(in project: String? = nil) {
        let projectName = project ?? selectedSession?.projectName
        let workingDir = selectedSession?.workingDir
        let session = ChatSession(
            title: "New chat",
            preview: "Start a conversation…",
            updatedAt: .now,
            messages: [],
            projectName: projectName,
            workingDir: workingDir
        )
        sessions.insert(session, at: 0)
        selectedSessionID = session.id
        draft = ""
        selectedChangeFileID = nil
        isComposerFocused = true
    }


    func delete(_ session: ChatSession) {
        sessions.removeAll { $0.id == session.id }
        if selectedSessionID == session.id {
            selectedSessionID = sessions.first?.id
            selectedChangeFileID = nil
        }
    }

    func sendDraft() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        guard let id = selectedSessionID,
              let index = sessions.firstIndex(where: { $0.id == id }) else {
            // No session — create one
            var session = ChatSession(
                title: String(text.prefix(48)),
                preview: text,
                updatedAt: .now,
                messages: [
                    ChatMessage(role: .user, text: text)
                ]
            )
            // Fake assistant reply for UI testing
            session.messages.append(fakeAssistantReply(to: text))
            sessions.insert(session, at: 0)
            selectedSessionID = session.id
            draft = ""
            return
        }

        sessions[index].messages.append(ChatMessage(role: .user, text: text))
        sessions[index].messages.append(fakeAssistantReply(to: text))
        sessions[index].preview = text
        sessions[index].updatedAt = .now
        if sessions[index].title == "New chat" {
            sessions[index].title = String(text.prefix(48))
        }
        draft = ""
    }

    func applySuggestion(_ suggestion: PromptSuggestion) {
        draft = suggestion.title
        isComposerFocused = true
    }

    func setWorkingDir(_ path: String) {
        guard let id = selectedSessionID,
              let index = sessions.firstIndex(where: { $0.id == id }) else { return }
        sessions[index].workingDir = path
    }

    func isToolGroupExpanded(_ id: UUID) -> Bool {
        expandedToolGroups.contains(id)
    }

    func setToolGroup(_ id: UUID, expanded: Bool) {
        if expanded {
            expandedToolGroups.insert(id)
        } else {
            expandedToolGroups.remove(id)
        }
    }

    // MARK: - Fake reply

    private func fakeAssistantReply(to prompt: String) -> ChatMessage {
        ChatMessage(
            role: .assistant,
            text: """
            Got it — I'll treat this as a UI-only mock response.

            You asked: “\(prompt.prefix(160))\(prompt.count > 160 ? "…" : "")”

            In a real build this would stream from the model. For now, the layout, selection, and composer all work so you can poke at the interface.
            """,
            thinking: Thinking(
                summary: "Looked at the request and prepared a mock reply so the Mac UI can be reviewed.",
                full: "This is fake thinking text for the Mac UI. No model ran."
            ),
            tools: [
                ToolUse(name: "bash", detail: "command: ls -la"),
                ToolUse(name: "Read ChatStore.swift", detail: "Pi Dev Mac/Data/ChatStore.swift"),
                ToolUse(name: "Edit ComposerView.swift", detail: "+18 −4")
            ],
            terminal: [
                TerminalRun(
                    command: "ls -la",
                    output: "total 48\ndrwxr-xr-x  12 om  staff   384 Aug 14 12:00 .\ndrwxr-xr-x   8 om  staff   256 Aug 14 11:40 .."
                )
            ],
            createdAt: .now.addingTimeInterval(0.5)
        )
    }
}
