//
//  ToolUse.swift
//  Pi Dev
//

import Foundation

struct ToolUse: Identifiable {
  let id = UUID()
  let kind: ToolKind
  let name: String
  let detail: String
  let symbol: String
  /// The protocol-level toolCallId, used to attach execution results
  /// (terminal output) to the matching call.
  var callId: String? = nil
}
