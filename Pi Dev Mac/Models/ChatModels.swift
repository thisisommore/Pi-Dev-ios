//
//  ChatModels.swift
//  Pi Dev Mac
//

import Foundation
import SwiftUI

// MARK: - Message

enum MessageRole: String, Codable, Sendable {
    case user
    case assistant
}

struct ChatMessage: Identifiable, Hashable, Sendable {
    let id: UUID
    let role: MessageRole
    var text: String
    var codeBlocks: [CodeBlock]
    var createdAt: Date

    init(
        id: UUID = UUID(),
        role: MessageRole,
        text: String,
        codeBlocks: [CodeBlock] = [],
        createdAt: Date = .now
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.codeBlocks = codeBlocks
        self.createdAt = createdAt
    }
}

struct CodeBlock: Identifiable, Hashable, Sendable {
    let id: UUID
    var language: String
    var source: String

    init(id: UUID = UUID(), language: String, source: String) {
        self.id = id
        self.language = language
        self.source = source
    }
}

// MARK: - File change

struct FileChange: Identifiable, Hashable, Sendable {
    let id: UUID
    var path: String
    var additions: Int
    var deletions: Int
    var diff: String

    init(
        id: UUID = UUID(),
        path: String,
        additions: Int,
        deletions: Int,
        diff: String
    ) {
        self.id = id
        self.path = path
        self.additions = additions
        self.deletions = deletions
        self.diff = diff
    }

    var fileName: String {
        (path as NSString).lastPathComponent
    }
}

// MARK: - Session

struct ChatSession: Identifiable, Hashable, Sendable {
    let id: UUID
    var title: String
    var preview: String
    var updatedAt: Date
    var messages: [ChatMessage]
    var projectName: String?
    var fileChanges: [FileChange]

    init(
        id: UUID = UUID(),
        title: String,
        preview: String = "",
        updatedAt: Date = .now,
        messages: [ChatMessage] = [],
        projectName: String? = nil,
        fileChanges: [FileChange] = []
    ) {
        self.id = id
        self.title = title
        self.preview = preview
        self.updatedAt = updatedAt
        self.messages = messages
        self.projectName = projectName
        self.fileChanges = fileChanges
    }

    var relativeUpdated: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: updatedAt, relativeTo: .now)
    }
}

// MARK: - Model option

struct AIModelOption: Identifiable, Hashable, Sendable {
    let id: String
    var name: String
    var subtitle: String
    var symbol: String

    static let catalog: [AIModelOption] = [
        .init(id: "pi-5.6-xhigh", name: "5.6 Terra", subtitle: "Best quality", symbol: "sparkles"),
        .init(id: "pi-5.6", name: "5.6 Terra", subtitle: "Balanced", symbol: "bolt.fill"),
        .init(id: "pi-haiku", name: "Haiku 4.5 Extended", subtitle: "Fast replies", symbol: "hare.fill"),
        .init(id: "pi-code", name: "Pi Code", subtitle: "Optimized for coding", symbol: "curlybraces")
    ]
}

// MARK: - Thinking level

struct ThinkingLevel: Identifiable, Hashable, Sendable {
    let id: String
    var displayName: String
    var subtitle: String
    var symbol: String

    static let off = ThinkingLevel(
        id: "off",
        displayName: "Off",
        subtitle: "No extended thinking",
        symbol: "circle.slash"
    )
    static let minimal = ThinkingLevel(
        id: "minimal",
        displayName: "Minimal",
        subtitle: "~1k thinking tokens",
        symbol: "gauge.with.dots.needle.0percent"
    )
    static let low = ThinkingLevel(
        id: "low",
        displayName: "Low",
        subtitle: "~4k thinking tokens",
        symbol: "gauge.with.dots.needle.33percent"
    )
    static let medium = ThinkingLevel(
        id: "medium",
        displayName: "Medium",
        subtitle: "~16k thinking tokens",
        symbol: "gauge.with.dots.needle.50percent"
    )
    static let high = ThinkingLevel(
        id: "high",
        displayName: "High",
        subtitle: "~64k thinking tokens",
        symbol: "gauge.with.dots.needle.100percent"
    )

    static let all: [ThinkingLevel] = [off, minimal, low, medium, high]
}

// MARK: - Prompt suggestion

struct PromptSuggestion: Identifiable, Hashable, Sendable {
    let id: UUID
    var title: String
    var symbol: String
    var tint: Color

    init(id: UUID = UUID(), title: String, symbol: String, tint: Color) {
        self.id = id
        self.title = title
        self.symbol = symbol
        self.tint = tint
    }

    static let emptyState: [PromptSuggestion] = [
        .init(title: "Explore and understand code", symbol: "magnifyingglass", tint: .blue),
        .init(title: "Build a new feature, app, or tool", symbol: "hammer.fill", tint: .purple),
        .init(title: "Review code and suggest changes", symbol: "checkmark.seal.fill", tint: .green)
    ]
}
