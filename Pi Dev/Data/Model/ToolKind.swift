//
//  ToolKind.swift
//  Pi Dev
//

import SwiftUI

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
    case .mcp:     .primary
    case .skill:   .primary.opacity(0.65)
    case .builtin: .secondary
    }
  }
}
