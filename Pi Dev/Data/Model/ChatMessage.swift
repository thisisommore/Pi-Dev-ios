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
}
