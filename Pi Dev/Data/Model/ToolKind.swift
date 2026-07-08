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
    case .mcp:     .blue
    case .skill:   .pink
    case .builtin: .green
    }
  }
}
