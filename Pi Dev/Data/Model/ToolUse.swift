//
//  ToolUse.swift
//  Pi Dev
//

import Foundation

struct ToolUse: Identifiable {
  let id = UUID()
  /// Server tool-call id used to attach execution results.
  var toolCallId: String? = nil
  let kind: ToolKind
  let name: String
  let detail: String
  let symbol: String
  /// Tool stdout / result text once execution finishes.
  var output: String? = nil
  var exitCode: Int? = nil
}
