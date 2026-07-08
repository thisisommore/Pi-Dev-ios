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
}
