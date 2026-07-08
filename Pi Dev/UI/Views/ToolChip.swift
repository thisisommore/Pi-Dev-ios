//
//  ToolChip.swift
//  Pi Dev
//

import SwiftUI

struct ToolRow: View {
  let tools: [ToolUse]

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      ForEach(tools) { tool in
        ToolChip(tool: tool)
      }
    }
  }
}

struct ToolChip: View {
  let tool: ToolUse

  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: tool.symbol)
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(.secondary)
        .frame(width: 18)

      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 6) {
          Text(tool.name)
            .font(.caption2.weight(.semibold))
          if isDiffStat(tool.detail) {
            DiffLabel(text: tool.detail)
          }
          Spacer(minLength: 0)
        }
        if !isDiffStat(tool.detail) {
          DiffLabel(text: tool.detail)
            .lineLimit(1)
        }
      }

      Spacer(minLength: 0)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(.secondary.opacity(0.08), in: .rect(cornerRadius: 12))
  }
}

private func isDiffStat(_ text: String) -> Bool {
  let parts = text.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
  return parts.contains { $0.hasPrefix("+") || $0.hasPrefix("−") || $0.hasPrefix("-") }
}

struct DiffLabel: View {
  let text: String

  var body: some View {
    HStack(spacing: 4) {
      ForEach(parts, id: \.self) { part in
        Text(part)
          .foregroundStyle(color(for: part))
      }
    }
    .font(.caption2)
  }

  private var parts: [String] {
    text.split(separator: " ", omittingEmptySubsequences: true)
      .map(String.init)
  }

  private func color(for part: String) -> Color {
    if part.hasPrefix("+") { return .green }
    if part.hasPrefix("−") || part.hasPrefix("-") { return .red }
    return .secondary
  }
}
