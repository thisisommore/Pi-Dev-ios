//
//  ChatMessage.swift
//  Pi Dev
//

import Foundation

struct ChatMessage: Identifiable {
  enum Role { case user, assistant }

  /// A rendered piece of an assistant message, kept in arrival order so the
  /// view can interleave text and tool calls exactly as they were produced.
  enum Segment: Identifiable {
    case text(id: UUID = UUID(), text: String)
    case tool(ToolUse)
    case terminal(TerminalRun)

    var id: UUID {
      switch self {
      case .text(let id, _): return id
      case .tool(let tool): return tool.id
      case .terminal(let run): return run.id
      }
    }
  }

  let id = UUID()
  var entryId: String? = nil
  let role: Role
  var text: String
  var code: (language: String, source: String)? = nil
  var thinking: Thinking? = nil
  var tools: [ToolUse] = []
  var terminal: [TerminalRun] = []
  var segments: [Segment] = []
  var tokens: Int = 0
  var isStreaming: Bool = false
  var error: String? = nil

  /// Content equality for cache/network revalidation (ignores local UUIDs).
  /// Used to skip UI updates when a refresh returns the same transcript.
  static func contentMatches(_ lhs: [ChatMessage], _ rhs: [ChatMessage]) -> Bool {
    guard lhs.count == rhs.count else { return false }
    for (a, b) in zip(lhs, rhs) {
      if a.entryId != b.entryId { return false }
      if a.role != b.role { return false }
      if a.text != b.text { return false }
      if a.tokens != b.tokens { return false }
      if a.error != b.error { return false }
      if a.isStreaming != b.isStreaming { return false }
      if a.code?.language != b.code?.language || a.code?.source != b.code?.source { return false }
      if a.thinking?.full != b.thinking?.full { return false }
      if a.thinking?.summary != b.thinking?.summary { return false }
      if a.tools.count != b.tools.count { return false }
      for (t0, t1) in zip(a.tools, b.tools) {
        if t0.name != t1.name || t0.detail != t1.detail || t0.kind != t1.kind { return false }
      }
      if a.terminal.count != b.terminal.count { return false }
      for (r0, r1) in zip(a.terminal, b.terminal) {
        if r0.command != r1.command || r0.output != r1.output || r0.exitCode != r1.exitCode {
          return false
        }
      }
      if a.segments.count != b.segments.count { return false }
      for (s0, s1) in zip(a.segments, b.segments) {
        switch (s0, s1) {
        case (.text(_, let t0), .text(_, let t1)):
          if t0 != t1 { return false }
        case (.tool(let t0), .tool(let t1)):
          if t0.name != t1.name || t0.detail != t1.detail { return false }
        case (.terminal(let r0), .terminal(let r1)):
          if r0.command != r1.command || r0.output != r1.output || r0.exitCode != r1.exitCode {
            return false
          }
        default:
          return false
        }
      }
    }
    return true
  }
}
