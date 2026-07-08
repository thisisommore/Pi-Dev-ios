//
//  ChatMessage.swift
//  Pi Dev
//

import Foundation

struct ChatMessage: Identifiable {
  enum Role { case user, assistant }

  let id = UUID()
  var entryId: String? = nil
  let role: Role
  var text: String
  var code: (language: String, source: String)? = nil
  var thinking: Thinking? = nil
  var tools: [ToolUse] = []
  var terminal: [TerminalRun] = []
  var tokens: Int = 0
  var isStreaming: Bool = false
}
