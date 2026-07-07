//
//  AICodeChat.swift
//  A single-file, UI-only SwiftUI prototype of an AI coding assistant.
//
//  ▸ Fake data only — no networking, no persistence.
//  ▸ Built for iOS 26+ (Liquid Glass: .glassEffect, GlassEffectContainer, .glass button styles).
//  ▸ Features: send/receive, model + thinking-level switching, context-left gauge,
//    expandable thinking blocks (summary / truncated / full), tool + MCP + skill chips,
//    terminal command output, and new-chat-from-scratch.
//

import SwiftUI
internal import UniformTypeIdentifiers

// MARK: - ── Domain (fake) ─────────────────────────────────────────────────────

enum AIModel: String, CaseIterable, Identifiable {
    case fable = "Fable 5"
    case opus = "Opus 4.8"
    case sonnet = "Sonnet 4.6"
    case haiku = "Haiku 4.5"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .fable:  "sparkles"
        case .opus:   "brain.head.profile"
        case .sonnet: "bolt.fill"
        case .haiku:  "wind"
        }
    }

    var blurb: String {
        switch self {
        case .fable:  "Deepest reasoning · slow"
        case .opus:   "Frontier coding · balanced"
        case .sonnet: "Everyday coding · fast"
        case .haiku:  "Instant answers · fastest"
        }
    }

    var contextWindow: Int {
        switch self {
        case .fable:  1_000_000
        case .opus:   500_000
        case .sonnet: 200_000
        case .haiku:  200_000
        }
    }

    var tint: Color {
        switch self {
        case .fable:  .purple
        case .opus:   .indigo
        case .sonnet: .teal
        case .haiku:  .orange
        }
    }
}

enum ThinkingLevel: String, CaseIterable, Identifiable {
    case off = "Off"
    case low = "Low"
    case medium = "Medium"
    case high = "High"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .off:    "circle.slash"
        case .low:    "gauge.with.dots.needle.0percent"
        case .medium: "gauge.with.dots.needle.50percent"
        case .high:   "gauge.with.dots.needle.100percent"
        }
    }

    var budget: String {
        switch self {
        case .off:    "No extended thinking"
        case .low:    "~4k thinking tokens"
        case .medium: "~16k thinking tokens"
        case .high:   "~64k thinking tokens"
        }
    }
}

enum ToolKind {
    case mcp, skill, builtin

    var label: String {
        switch self {
        case .mcp:     "MCP"
        case .skill:   "Skill"
        case .builtin: "Tool"
        }
    }

    var tint: Color {
        switch self {
        case .mcp:     .blue
        case .skill:   .pink
        case .builtin: .green
        }
    }
}

struct ToolUse: Identifiable {
    let id = UUID()
    let kind: ToolKind
    let name: String
    let detail: String
    let symbol: String
}

struct TerminalRun: Identifiable {
    let id = UUID()
    let command: String
    let output: String
    let exitCode: Int
}

struct Thinking {
    var summary: String   // one-liner
    var truncated: String // short preview
    var full: String      // full trace
    let seconds: Int
}

struct PastedItem: Identifiable {
    let id = UUID()
    let content: String
}

struct ContextFile: Identifiable {
    let id = UUID()
    let name: String
    let content: String
}

struct ChatMessage: Identifiable {
    enum Role { case user, assistant }

    let id = UUID()
    let role: Role
    var text: String
    var code: (language: String, source: String)? = nil
    var thinking: Thinking? = nil
    var tools: [ToolUse] = []
    var terminal: [TerminalRun] = []
    var tokens: Int = 0
    var isStreaming: Bool = false
}

// MARK: - ── Store (fake state) ─────────────────────────────────────────────────

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

    var contextFraction: Double {
        min(1, Double(usedTokens) / Double(model.contextWindow))
    }

    init() { seed() }

    var editingMessageId: UUID? = nil
    var pastedItems: [PastedItem] = []
    var contextFiles: [ContextFile] = []

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
        guard !isResponding else { return }

        let pastedBody = pastedItems.map(\.content).joined(separator: "\n\n")
        let fileBody = contextFiles.map { "File: \($0.name)\n\($0.content)" }.joined(separator: "\n\n")
        let attachmentsBody = [pastedBody, fileBody].filter { !$0.isEmpty }.joined(separator: "\n\n")
        let body: String
        if draft.isEmpty && attachmentsBody.isEmpty {
            body = ""
        } else if draft.isEmpty {
            body = attachmentsBody
        } else if attachmentsBody.isEmpty {
            body = draft
        } else {
            body = draft + "\n\n" + attachmentsBody
        }
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
        if messages.isEmpty { chatTitle = String(trimmed.prefix(34)) }

        withAnimation(.snappy) {
            messages.append(ChatMessage(role: .user, text: trimmed, tokens: 180))
            usedTokens += 180
            isResponding = true
        }

        // Stream a fake reply character by character.
        Task { @MainActor in
            await streamReply(for: trimmed)
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

        let reply = Self.cannedReply(for: userText, level: self.thinkingLevel)
        let messageIndex = self.messages.count

        await MainActor.run {
            withAnimation(.snappy) {
                self.messages.append(ChatMessage(role: .assistant, text: "", tokens: 0, isStreaming: true))
                self.isResponding = false
            }
        }

        // Stream thinking summary first.
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

        // Stream main response text.
        await Self.stream(text: reply.text) { partial in
            if self.messages.indices.contains(messageIndex) {
                self.messages[messageIndex].text = partial
            }
        }

        // Reveal remaining content.
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
    }

    private static func stream(text: String, update: @escaping (String) -> Void) async {
        for i in 0..<text.count {
            let index = text.index(text.startIndex, offsetBy: i)
            let partial = String(text[...index])
            await MainActor.run {
                update(partial)
            }
            try? await Task.sleep(for: .milliseconds(12))
        }
    }

    private static func cannedReply(for prompt: String, level: ThinkingLevel) -> ChatMessage {
        var reply = ChatMessage(
            role: .assistant,
            text: "Done — I added a debounced search to the repository list. The query now waits 300 ms after the last keystroke, cancels stale requests, and falls back to the cached page when offline. Tests pass locally.",
            code: ("swift", """
            .task(id: query) {
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                results = await repo.search(query)
            }
            """),
            tokens: 2_600
        )
        if level != .off {
            reply.thinking = Thinking(
                summary: "Weighed Combine debounce vs task(id:) — chose task(id:) for structured cancellation.",
                truncated: "The user wants search-as-you-type without hammering the API. Options: Combine's debounce, an AsyncStream, or task(id:) keyed on the query. task(id:) auto-cancels the previous task when the query changes, which gives debounce + cancellation in four lines…",
                full: """
                The user wants search-as-you-type without hammering the API.

                Options considered:
                1. Combine `debounce` on a published query — works, but pulls Combine into an otherwise async/await codebase and needs manual cancellation of in-flight requests.
                2. Hand-rolled AsyncStream with a timer — flexible but ~30 lines of ceremony.
                3. `.task(id: query)` — SwiftUI cancels the previous task whenever `id` changes, so sleeping 300 ms at the top gives debounce and cancellation for free.

                Going with option 3. Edge cases: empty query should clear results immediately (skip the sleep); offline mode should serve the cached page — the repo layer already exposes `cachedSearch(_:)`, so I'll fall back there on URLError. I'll also key the cache by normalized query to avoid duplicate entries for "Swift " vs "swift".

                Verified by running the existing SearchViewModelTests plus two new cases: rapid-typing cancellation and offline fallback. All green.
                """,
                seconds: 14
            )
        }
        reply.tools = [
            ToolUse(kind: .mcp, name: "github", detail: "Read repository/SearchViewModel.swift", symbol: "arrow.triangle.branch"),
            ToolUse(kind: .skill, name: "swift-testing", detail: "Generated 2 test cases", symbol: "checkmark.seal"),
            ToolUse(kind: .builtin, name: "file_edit", detail: "3 files changed, +42 −11", symbol: "pencil.line"),
        ]
        reply.terminal = [
            TerminalRun(
                command: "swift test --filter SearchViewModelTests",
                output: "Test Suite 'SearchViewModelTests' passed\n  ✔ debouncesRapidTyping (0.31s)\n  ✔ fallsBackToCacheOffline (0.08s)\nExecuted 6 tests, 0 failures",
                exitCode: 0
            )
        ]
        return reply
    }

    private func seed() {
        chatTitle = "Debounce repo search"
        messages = [
            ChatMessage(role: .user,
                        text: "Search in the repo list fires an API call on every keystroke. Can you debounce it and add an offline fallback?",
                        tokens: 210),
            Self.cannedReply(for: "", level: .high),
        ]
        usedTokens = 46_800
    }
}

// MARK: - ── Sidebar store ─────────────────────────────────────────────────────

@Observable
final class SidebarStore {
    var chats: [ChatStore] = []
    var selectedChatId: UUID? = nil
    var searchText = ""

    init() {
        let first = ChatStore()
        chats = [first]
        selectedChatId = first.id
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

// MARK: - ── Root ──────────────────────────────────────────────────────────────

struct AICodeChatView: View {
    @State private var sidebarStore = SidebarStore()
    @State private var showSidebar = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let selectedChat = sidebarStore.chats.first(where: { $0.id == sidebarStore.selectedChatId }) {
                    ChatDetailView(store: selectedChat, showSidebar: $showSidebar)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ContentUnavailableView("Select a chat", systemImage: "bubble")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                // Dim detail when sidebar is open
                Color.black.opacity(showSidebar ? 0.25 : 0)
                    .ignoresSafeArea()
                    .contentShape(.rect)
                    .onTapGesture {
                        withAnimation(.snappy) {
                            showSidebar = false
                        }
                    }
                    .allowsHitTesting(showSidebar)
                    .animation(.snappy, value: showSidebar)

                // Slide-over sidebar: 80% width
                Sidebar(store: sidebarStore)
                    .frame(width: geometry.size.width * 0.8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .offset(x: showSidebar ? 0 : -geometry.size.width * 0.8)
                    .animation(.snappy, value: showSidebar)
            }
            .onChange(of: sidebarStore.selectedChatId) { _, _ in
                withAnimation(.snappy) {
                    showSidebar = false
                }
            }
        }
    }
}

private struct ChatDetailView: View {
    @Bindable var store: ChatStore
    @State private var showModelSheet = false
    @Binding var showSidebar: Bool

    var body: some View {
        ZStack {
            Background()

            VStack(spacing: 0) {
                Header(store: store, showModelSheet: $showModelSheet, showSidebar: $showSidebar)
                MessageList(store: store)
            }
            .contentShape(.rect)
            .onTapGesture {
                store.cancelEditIfUnchanged()
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(alignment: .leading, spacing: 0) {
                if store.editingMessageId != nil {
                    Button {
                        store.cancelEdit()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.gray)
                            .frame(width: 44, height: 44)
                            .background(.white, in: .circle)
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 16)
                    .padding(.bottom, 8)
                }
                Composer(store: store, showModelSheet: $showModelSheet)
            }
        }
        .sheet(isPresented: $showModelSheet) {
            ModelSheet(store: store)
                .presentationDetents([.medium])
                .presentationBackground(.thinMaterial)
                .presentationCornerRadius(32)
        }
    }
}

// MARK: - ── Sidebar ───────────────────────────────────────────────────────────

private struct Sidebar: View {
    @Bindable var store: SidebarStore

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            LinearGradient(
                colors: [.purple.opacity(0.08), .clear, .teal.opacity(0.06)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Text("Chats")
                        .font(.title3.weight(.bold))
                    Spacer()
                    Button {
                        store.newChat()
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(width: 36, height: 36)
                            .background(.white.opacity(0.12), in: .circle)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

                HStack {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                    TextField("Search chats…", text: $store.searchText)
                        .font(.subheadline)
                    if !store.searchText.isEmpty {
                        Button {
                            store.searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 15))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.secondary.opacity(0.12), in: .rect(cornerRadius: 12))
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(store.filteredChats) { chat in
                            Button {
                                store.select(chatId: chat.id)
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "bubble.fill")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                    Text(chat.chatTitle)
                                        .font(.subheadline.weight(.semibold))
                                        .lineLimit(1)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    if store.selectedChatId == chat.id {
                                        Circle()
                                            .fill(.white)
                                            .frame(width: 6, height: 6)
                                    }
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(
                                    store.selectedChatId == chat.id
                                        ? .white.opacity(0.14)
                                        : .clear,
                                    in: .rect(cornerRadius: 12)
                                )
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    store.delete(chatId: chat.id)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                }

                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - ── Background ────────────────────────────────────────────────────────

private struct Background: View {
    var body: some View {
        ZStack {
            Color(.systemBackground)
            LinearGradient(
                colors: [.purple.opacity(0.16), .clear, .teal.opacity(0.12)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            Circle()
                .fill(.purple.opacity(0.14))
                .frame(width: 380)
                .blur(radius: 110)
                .offset(x: -140, y: -280)
            Circle()
                .fill(.teal.opacity(0.12))
                .frame(width: 320)
                .blur(radius: 100)
                .offset(x: 150, y: 320)
        }
        .ignoresSafeArea()
    }
}

// MARK: - ── Header ────────────────────────────────────────────────────────────

private struct Header: View {
    @Bindable var store: ChatStore
    @Binding var showModelSheet: Bool
    @Binding var showSidebar: Bool
    @State private var showRenameAlert = false
    @State private var renameDraft = ""

    var body: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                // Sidebar toggle
                Button {
                    withAnimation(.snappy) {
                        showSidebar.toggle()
                    }
                } label: {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive())

                // New chat
                Button {
                    store.newChat()
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive())

                // Title with menu on tap
                Menu {
                    Button {
                        renameDraft = store.chatTitle
                        showRenameAlert = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    if !store.messages.isEmpty {
                        Button {
                            store.forkChat()
                        } label: {
                            Label("Fork", systemImage: "arrow.branch")
                        }
                    }
                } label: {
                    HStack {
                        Text(store.chatTitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .tint(.primary)
                .animation(nil)
                .frame(maxWidth: .infinity, alignment: .leading)

                // Context gauge
                ContextGauge(fraction: store.contextFraction,
                             used: store.usedTokens,
                             window: store.model.contextWindow)
                    .frame(width: 44, height: 44)
                    .glassEffect(.regular)
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 10)
        }
        .blur(radius: store.editingMessageId != nil ? 10 : 0)
        .allowsHitTesting(store.editingMessageId == nil)
        .animation(.snappy, value: store.editingMessageId != nil)
        .alert("Rename chat", isPresented: $showRenameAlert) {
            TextField("Chat name", text: $renameDraft)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                let trimmed = renameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    store.chatTitle = trimmed
                }
            }
        }
    }
}

private struct ContextGauge: View {
    let fraction: Double
    let used: Int
    let window: Int

    private var remaining: Int { max(0, window - used) }

    var body: some View {
        Menu {
            Section("Context window") {
                Label("\(remaining.compactFormatted) tokens left", systemImage: "gauge.open.with.lines.needle.33percent")
                Label("\(used.compactFormatted) of \(window.compactFormatted) used", systemImage: "chart.pie")
            }
        } label: {
            ZStack {
                Circle()
                    .stroke(.quaternary, lineWidth: 3.5)
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(.white.gradient, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .padding(9)
            .animation(.snappy, value: fraction)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Context remaining \(Int((1 - fraction) * 100)) percent")
    }
}

// MARK: - ── Message list ──────────────────────────────────────────────────────

private struct MessageList: View {
    @Bindable var store: ChatStore

    var body: some View {
        if store.messages.isEmpty {
            EmptyChatView()
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 18) {
                        ForEach(store.messages) { message in
                            MessageRow(message: message, store: store)
                                .id(message.id)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .bottom).combined(with: .opacity),
                                    removal: .opacity))
                        }
                        if store.isResponding {
                            TypingIndicator(tint: store.model.tint)
                                .id("typing")
                                .transition(.opacity)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                }
                .frame(maxHeight: .infinity)
                .scrollDismissesKeyboard(.interactively)
                .scrollEdgeEffectStyle(.soft, for: .all)
                .onChange(of: store.messages.count) {
                    withAnimation(.snappy) {
                        proxy.scrollTo(store.messages.last?.id, anchor: .bottom)
                    }
                }
            }
        }
    }
}

private struct EmptyChatView: View {
    var body: some View {
        Text("π")
            .font(.system(size: 32, weight: .thin, design: .serif))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct MessageRow: View {
    let message: ChatMessage
    @Bindable var store: ChatStore

    private var isBeingEdited: Bool { store.editingMessageId == message.id }
    private var isBlurred: Bool { store.editingMessageId != nil && !isBeingEdited }

    var body: some View {
        Group {
            switch message.role {
            case .user:      UserBubble(message: message, store: store)
            case .assistant: AssistantMessage(message: message, store: store)
            }
        }
        .scaleEffect(isBeingEdited ? 1.04 : 1)
        .blur(radius: isBlurred ? 10 : 0)
        .opacity(isBlurred ? 0.4 : 1)
        .allowsHitTesting(!isBlurred)
        .animation(.snappy, value: store.editingMessageId)
    }
}

// MARK: - User bubble

private struct UserBubble: View {
    let message: ChatMessage
    @Bindable var store: ChatStore

    var body: some View {
        HStack {
            Spacer(minLength: 56)
            Text(message.text)
                .font(.callout)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .foregroundStyle(.white)
                .background(
                    Color.purple,
                    in: .rect(cornerRadius: 22)
                )
                .glassEffect(.clear, in: .rect(cornerRadius: 22))
                .contextMenu {
                    Button {
                        UIPasteboard.general.string = message.text
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                    Button {
                        store.startEditing(message: message)
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                }
        }
    }
}

// MARK: - Assistant message

private struct AssistantMessage: View {
    let message: ChatMessage
    @Bindable var store: ChatStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let thinking = message.thinking {
                ThinkingBlock(thinking: thinking)
            }
            ForEach(message.terminal) { run in
                TerminalBlock(run: run)
            }

            Text(message.text)
                .font(.callout)
                .lineSpacing(3)
                .textSelection(.enabled)

            if let code = message.code {
                CodeBlock(language: code.language, source: code.source)
            }

            HStack(spacing: 10) {
                Text("\(message.tokens.compactFormatted) tok")
                ActionIcon("doc.on.doc")
                RetryButton(message: message, store: store)
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
    }
}

private struct ActionIcon: View {
    let symbol: String
    init(_ symbol: String) { self.symbol = symbol }
    var body: some View {
        Button {} label: {
            Image(systemName: symbol).font(.system(size: 12))
        }
        .buttonStyle(.plain)
    }
}

private struct RetryButton: View {
    let message: ChatMessage
    @Bindable var store: ChatStore

    var body: some View {
        Menu {
            Button {
                store.retry(from: message.id)
            } label: {
                Label("Retry", systemImage: "arrow.clockwise")
            }
            Button {
                store.retryWithDifferentSettings(from: message.id)
            } label: {
                Label("Retry with different settings", systemImage: "slider.horizontal.3")
            }
        } label: {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Thinking block (summary → truncated → full)

private struct ThinkingBlock: View {
    let thinking: Thinking

    @State private var showSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.snappy) { showSheet = true }
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "brain")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .symbolEffect(.pulse, isActive: false)
                    Text("Thought for \(thinking.seconds)s")
                        .font(.caption.weight(.semibold))
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .rotationEffect(.degrees(showSheet ? 180 : 0))
                        .foregroundStyle(.secondary)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            Text(thinking.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 8)
        .sheet(isPresented: $showSheet) {
            ThinkingSheet(thinking: thinking)
                .presentationDetents([.large])
                .presentationBackground(.thinMaterial)
                .presentationCornerRadius(32)
        }
    }
}

private struct ThinkingSheet: View {
    let thinking: Thinking

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Capsule()
                .fill(.tertiary)
                .frame(width: 36, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)

            Text("Thinking · \(thinking.seconds)s")
                .font(.title3.weight(.bold))
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 8)

            ScrollView {
                Text(thinking.full)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
            }
        }
    }
}

// MARK: - Tool / MCP / skill chips

private struct ToolRow: View {
    let tools: [ToolUse]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(tools) { tool in
                    ToolChip(tool: tool)
                }
            }
        }
        .scrollClipDisabled()
    }
}

private struct ToolChip: View {
    let tool: ToolUse
    @State private var expanded = false

    var body: some View {
        Button {
            withAnimation(.snappy) { expanded.toggle() }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: tool.symbol)
                    .font(.system(size: 10, weight: .semibold))
                Text(tool.name)
                    .font(.caption2.weight(.semibold))
                Text(tool.kind.label)
                    .font(.system(size: 8, weight: .heavy))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(tool.kind.tint.opacity(0.18), in: .capsule)
                if expanded {
                    Text(tool.detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .transition(.opacity)
                }
            }
            .foregroundStyle(tool.kind.tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.tint(tool.kind.tint.opacity(0.1)).interactive(), in: .capsule)
    }
}

// MARK: - Terminal block

private struct TerminalBlock: View {
    let run: TerminalRun
    @State private var expanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.snappy) { expanded.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Text(run.command)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: run.exitCode == 0 ? "checkmark" : "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(run.exitCode == 0 ? .white : .red)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            if expanded {
                Divider().opacity(0.4)
                Text(run.output)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .transition(.opacity)
            }
        }
        .background(.black.opacity(0.25), in: .rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        )
    }
}

// MARK: - Code block

private struct CodeBlock: View {
    let language: String
    let source: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(language.uppercased())
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {} label: {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(.system(size: 10, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider().opacity(0.4)

            ScrollView(.horizontal, showsIndicators: false) {
                Text(source)
                    .font(.system(size: 12, design: .monospaced))
                    .padding(12)
                    .textSelection(.enabled)
            }
        }
        .background(.black.opacity(0.22), in: .rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        )
    }
}

// MARK: - Typing indicator

private struct TypingIndicator: View {
    let tint: Color
    @State private var phase = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "brain")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
                .symbolEffect(.pulse, isActive: true)
            Text("Thinking…")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            HStack(spacing: 3) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(tint)
                        .frame(width: 5, height: 5)
                        .opacity(phase ? 1 : 0.25)
                        .animation(.easeInOut(duration: 0.6).repeatForever().delay(Double(i) * 0.18),
                                   value: phase)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: .capsule)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear { phase = true }
    }
}

// MARK: - ── Composer ──────────────────────────────────────────────────────────

private struct Composer: View {
    @Bindable var store: ChatStore
    @Binding var showModelSheet: Bool
    @FocusState private var focused: Bool
    @State private var selectedPastedItem: PastedItem?
    @State private var selectedContextFile: ContextFile?
    @State private var showFileImporter = false
    @State private var showClearAlert = false

    private var hasAttachments: Bool { !store.pastedItems.isEmpty || !store.contextFiles.isEmpty }

    var body: some View {
        GlassEffectContainer(spacing: 10) {
            VStack(spacing: 10) {
                // Removed the model selector pill from quick controls
                HStack(spacing: 8) {
                    Spacer()
                }
                .padding(.horizontal, 16)

                // Input + buttons container
                VStack(spacing: 0) {
                    if hasAttachments {
                        HStack {
                            Spacer()
                            Button("Clear all") {
                                showClearAlert = true
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(store.pastedItems) { item in
                                    attachmentCard(
                                        icon: "doc.on.clipboard",
                                        title: "Pasted",
                                        preview: item.content,
                                        onTap: { selectedPastedItem = item },
                                        onRemove: {
                                            withAnimation(.snappy) {
                                                store.pastedItems.removeAll { $0.id == item.id }
                                            }
                                        }
                                    )
                                }
                                ForEach(store.contextFiles) { file in
                                    attachmentCard(
                                        icon: "doc.text",
                                        title: file.name,
                                        preview: file.content,
                                        onTap: { selectedContextFile = file },
                                        onRemove: {
                                            withAnimation(.snappy) {
                                                store.contextFiles.removeAll { $0.id == file.id }
                                            }
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.top, 6)
                        }
                        .scrollClipDisabled()
                    }

                    TextField(store.editingMessageId != nil ? "Edit message…" : "Ask about your code…", text: $store.draft, axis: .vertical)
                        .lineLimit(1...5)
                        .focused($focused)
                        .font(.callout)
                        .onSubmit { store.send() }
                        .onChange(of: store.editingMessageId) { _, id in
                            if id != nil { focused = true }
                        }
                        .onChange(of: store.draft) { oldValue, newValue in
                            guard store.editingMessageId == nil else { return }
                            let delta = newValue.count - oldValue.count
                            if delta > 3 && newValue.count > 50 {
                                store.pastedItems.append(PastedItem(content: newValue))
                                store.draft = ""
                            }
                        }
                        .padding(.top, hasAttachments ? 8 : 14)
                        .padding(.horizontal, 14)

                    HStack(spacing: 8) {
                        Menu {
                            Picker("Thinking", selection: $store.thinkingLevel) {
                                ForEach(ThinkingLevel.allCases) { level in
                                    Label {
                                        Text(level.rawValue)
                                        Text(level.budget)
                                    } icon: {
                                        Image(systemName: level.symbol)
                                    }
                                    .tag(level)
                                }
                            }
                        } label: {
                            PillLabel(symbol: "brain",
                                      text: " \(store.thinkingLevel.rawValue)")
                        }
                        .buttonStyle(.plain)
                        .glassEffect(.regular.interactive(), in: .capsule)

                        // Model selector pill moved here
                        Button {
                            showModelSheet = true
                        } label: {
                            PillLabel(symbol: nil, text: store.model.rawValue)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(.regular.interactive(), in: .capsule)

                        Spacer()

                        Button {
                            showFileImporter = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .semibold))
                                .frame(width: 40, height: 40)
                        }
                        .buttonStyle(.plain)

                        Button {
                            store.send()
                        } label: {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 15, weight: .bold))
                                .frame(width: 40, height: 40)
                                .foregroundStyle(.white)
                                .background(
                                    store.draft.isEmpty
                                        ? AnyShapeStyle(.gray.opacity(0.4))
                                        : AnyShapeStyle(store.model.tint.gradient),
                                    in: .circle
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled((store.draft.isEmpty && store.pastedItems.isEmpty && store.contextFiles.isEmpty) || store.isResponding)
                        .animation(.snappy, value: store.draft.isEmpty && store.pastedItems.isEmpty && store.contextFiles.isEmpty)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                }
                .background(.regularMaterial, in: .rect(cornerRadius: 26))
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.plainText, .sourceCode, .data], allowsMultipleSelection: true) { result in
            importFiles(from: result)
        }
        .sheet(item: $selectedPastedItem) { item in
            PastedSheet(item: item)
                .presentationDetents([.medium])
                .presentationBackground(.thinMaterial)
                .presentationCornerRadius(32)
        }
        .sheet(item: $selectedContextFile) { file in
            ContextFileSheet(file: file)
                .presentationDetents([.medium])
                .presentationBackground(.thinMaterial)
                .presentationCornerRadius(32)
        }
        .alert("Clear all attachments?", isPresented: $showClearAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                withAnimation(.snappy) {
                    store.pastedItems = []
                    store.contextFiles = []
                }
            }
        } message: {
            Text("This will remove all attachments")
        }
    }

    private func attachmentCard(icon: String, title: String, preview: String, onTap: @escaping () -> Void, onRemove: @escaping () -> Void) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: icon)
                            .font(.system(size: 11, weight: .semibold))
                        Text(title)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                    }
                    Text(String(preview.prefix(200)))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
                    .background(.secondary.opacity(0.15), in: .circle)
            }
            .buttonStyle(.plain)
        }
        .frame(width: 150, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.white.opacity(0.12), in: .rect(cornerRadius: 12))
    }

    private func importFiles(from result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            Task { @MainActor in
                for url in urls {
                    let gotAccess = url.startAccessingSecurityScopedResource()
                    defer { if gotAccess { url.stopAccessingSecurityScopedResource() } }
                    if let content = try? String(contentsOf: url, encoding: .utf8) {
                        let name = url.lastPathComponent
                        store.contextFiles.append(ContextFile(name: name, content: content))
                    }
                }
            }
        case .failure:
            break
        }
    }
}

private struct PastedSheet: View {
    let item: PastedItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Capsule()
                .fill(.tertiary)
                .frame(width: 36, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)

            Text("Pasted content")
                .font(.title3.weight(.bold))
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 8)

            ScrollView {
                Text(item.content)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                    .textSelection(.enabled)
            }
        }
    }
}

private struct ContextFileSheet: View {
    let file: ContextFile
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Capsule()
                .fill(.tertiary)
                .frame(width: 36, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)

            Text(file.name)
                .font(.title3.weight(.bold))
                .lineLimit(1)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 8)

            ScrollView {
                Text(file.content)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                    .textSelection(.enabled)
            }
        }
    }
}

private struct PillLabel: View {
    let symbol: String?
    let text: String

    var body: some View {
        HStack(spacing: 5) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 10, weight: .semibold))
            }
            Text(text)
                .font(.caption.weight(.semibold))
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 7, weight: .bold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .contentShape(.capsule)
    }
}

// MARK: - ── Model sheet ───────────────────────────────────────────────────────

private struct ModelSheet: View {
    @Bindable var store: ChatStore
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filteredModels: [AIModel] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if query.isEmpty { return AIModel.allCases }
        return AIModel.allCases.filter { $0.rawValue.lowercased().contains(query) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Capsule()
                .fill(.tertiary)
                .frame(width: 36, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)

            searchBar

            ModelList(store: store, models: filteredModels)

            Spacer(minLength: 0)
        }
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
            TextField("Search models…", text: $searchText)
                .font(.subheadline)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.secondary.opacity(0.12), in: .rect(cornerRadius: 14))
        .padding(.horizontal, 20)
    }
}

private struct ModelList: View {
    @Bindable var store: ChatStore
    @Environment(\.dismiss) private var dismiss
    let models: [AIModel]

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(models) { model in
                    ModelRow(store: store, model: model)

                    if model != models.last {
                        Divider()
                            .padding(.leading, 20)
                    }
                }
            }
            .background(.secondary.opacity(0.12), in: .rect(cornerRadius: 16))
            .clipShape(.rect(cornerRadius: 16))
            .padding(.horizontal, 16)
            .padding(.top, 4)
        }
    }
}

private struct ModelRow: View {
    @Bindable var store: ChatStore
    @Environment(\.dismiss) private var dismiss
    let model: AIModel

    var body: some View {
        Button {
            withAnimation(.snappy) { store.model = model }
            dismiss()
        } label: {
            HStack {
                Text(model.rawValue)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if store.model == model {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .background(store.model == model ? Color.white.opacity(0.16) : .clear, in: .rect(cornerRadius: 0))
    }
}

// MARK: - ── Helpers ───────────────────────────────────────────────────────────

extension Int {
    var compactFormatted: String {
        switch self {
        case 1_000_000...: String(format: "%.1fM", Double(self) / 1_000_000).replacingOccurrences(of: ".0M", with: "M")
        case 1_000...:     String(format: "%.1fK", Double(self) / 1_000).replacingOccurrences(of: ".0K", with: "K")
        default:           "\(self)"
        }
    }
}

// MARK: - ── Preview ───────────────────────────────────────────────────────────

#Preview {
    AICodeChatView()
        .preferredColorScheme(.dark)
}

