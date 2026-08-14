//
//  ChatStore+Segments.swift
//  Pi Dev
//

import Observation
import SwiftUI

extension ChatStore {
  /// Builds ordered render segments from message content blocks. Returns nil when the
  /// content is missing, so callers keep whatever was accumulated while streaming.
  func buildSegments(from content: AgentMessage.MessageContent?) -> (segments: [ChatMessage.Segment], text: String, code: (language: String, source: String)?)? {
    guard let content else { return nil }

    let blocks: [AgentMessage.ContentBlock]
    switch content {
    case .text(let string):
      blocks = [.text(string)]
    case .blocks(let contentBlocks):
      blocks = contentBlocks
    }

    var segments: [ChatMessage.Segment] = []
    for block in blocks {
      switch block {
      case .text(let rawText):
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
          segments.append(.text(text: trimmed))
        }
      case .toolCall(let call):
        let detail = formatToolDetail(name: call.name, arguments: call.arguments)
        segments.append(.tool(ToolUse(kind: toolKind(for: call.name), name: call.name, detail: detail, symbol: toolSymbol(for: call.name), callId: call.id)))
      case .thinking, .unknown:
        break
      }
    }

    let text = segments.compactMap { segment -> String? in
      guard case .text(_, let text) = segment else { return nil }
      return text
    }.joined(separator: "\n\n")

    return (segments, text, nil)
  }

  func stripFirstCodeBlock(from text: String) -> (text: String, code: (language: String, source: String)?) {
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

  func toolKind(for name: String) -> ToolKind {
    if name.hasPrefix("mcp/") || name.lowercased().contains("mcp") { return .mcp }
    if name.hasPrefix("skill/") || name.lowercased().contains("skill") { return .skill }
    return .builtin
  }

  func toolSymbol(for name: String) -> String {
    switch name.lowercased() {
    case let n where n.contains("search"): return "magnifyingglass"
    case let n where n.contains("edit") || n.contains("write"): return "pencil.line"
    case let n where n.contains("read"): return "doc.text"
    case let n where n.contains("bash") || n.contains("run"): return "terminal"
    case let n where n.contains("test"): return "checkmark.seal"
    default: return "gearshape.2"
    }
  }

  /// Prefer the primary value for single-arg tools (bash command, file path).
  /// Fall back to stable "key: value" lines for multi-arg calls.
  func formatToolDetail(name: String, arguments: [String: AnyCodable]?) -> String {
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

  func preferredDetailKeys(for name: String) -> [String] {
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

  func stringValue(_ value: Any) -> String {
    switch value {
    case let s as String: return s
    case let n as NSNumber: return n.stringValue
    case let b as Bool: return b ? "true" : "false"
    case is NSNull: return ""
    default: return "\(value)"
    }
  }
}

