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

  private var isDiff: Bool { isDiffStat(tool.detail) }
  private var isCommand: Bool {
    let n = tool.name.lowercased()
    return n == "bash" || n.contains("bash") || n.contains("run") || n.contains("shell")
      || tool.detail.hasPrefix("command:")
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack(alignment: .firstTextBaseline, spacing: 6) {
        Text(tool.name)
          .font(.caption)
          .foregroundStyle(.secondary)

        if isDiff {
          DiffLabel(text: tool.detail)
        }

        Spacer(minLength: 0)
      }

      if !tool.detail.isEmpty && !isDiff {
        Text(displayDetail)
          .font(isCommand
                ? .system(size: 12, design: .monospaced)
                : .caption)
          .foregroundStyle(.primary.opacity(0.75))
          .lineLimit(3)
          .multilineTextAlignment(.leading)
          .fixedSize(horizontal: false, vertical: true)
          .frame(maxWidth: .infinity, alignment: .leading)
          .textSelection(.enabled)
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.secondary.opacity(0.08), in: .rect(cornerRadius: 12))
  }

  /// Strip noisy `key: ` prefixes for common single-arg tools.
  private var displayDetail: String {
    let detail = tool.detail.trimmingCharacters(in: .whitespacesAndNewlines)
    if detail.isEmpty { return detail }

    if let stripped = stripSingleKeyPrefix(detail, key: "command") { return stripped }
    if let stripped = stripSingleKeyPrefix(detail, key: "path") { return stripped }
    if let stripped = stripSingleKeyPrefix(detail, key: "file") { return stripped }

    return detail
  }

  private func stripSingleKeyPrefix(_ text: String, key: String) -> String? {
    let prefix = "\(key):"
    guard text.lowercased().hasPrefix(prefix) else { return nil }
    let rest = text.dropFirst(prefix.count).trimmingCharacters(in: .whitespacesAndNewlines)
    guard !rest.isEmpty, !rest.contains("\n") else { return nil }
    return rest
  }
}

/// True only for pure diff stats like "+41 −4" / "+28 -12".
private func isDiffStat(_ text: String) -> Bool {
  let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
  guard !trimmed.isEmpty else { return false }
  let parts = trimmed.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
  guard !parts.isEmpty else { return false }
  let isToken: (String) -> Bool = { part in
    guard let first = part.first, first == "+" || first == "-" || first == "−" else { return false }
    let digits = part.dropFirst()
    return !digits.isEmpty && digits.allSatisfy(\.isNumber)
  }
  return parts.allSatisfy(isToken)
}

struct DiffLabel: View {
  let text: String

  var body: some View {
    HStack(spacing: 4) {
      ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
        Text(part)
          .foregroundStyle(color(for: part))
      }
    }
    .font(.caption.monospacedDigit().weight(.medium))
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
