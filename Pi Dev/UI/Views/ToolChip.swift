//
//  ToolChip.swift
//  Pi Dev
//

import SwiftUI
import Combine

/// Collapsible wrapper for tool calls and terminal runs ("3 tools").
struct ToolsDisclosure: View {
  enum Item: Identifiable {
    case tool(ToolUse)
    case terminal(TerminalRun)

    var id: UUID {
      switch self {
      case .tool(let tool): return tool.id
      case .terminal(let run): return run.id
      }
    }
  }

  let items: [Item]
  @State private var expanded: Bool

  init(items: [Item], initiallyExpanded: Bool = false) {
    self.items = items
    _expanded = State(initialValue: initiallyExpanded)
  }

  init(tools: [ToolUse], terminal: [TerminalRun] = [], initiallyExpanded: Bool = false) {
    self.items = tools.map { .tool($0) } + terminal.map { .terminal($0) }
    _expanded = State(initialValue: initiallyExpanded)
  }

  private var title: String {
    let n = items.count
    return n == 1 ? "1 tool" : "\(n) tools"
  }

  var body: some View {
    if items.isEmpty {
      EmptyView()
    } else {
      VStack(alignment: .leading, spacing: 6) {
        Button {
          withAnimation(.snappy) { expanded.toggle() }
        } label: {
          HStack(spacing: 8) {
            Image(systemName: "wrench.and.screwdriver")
              .font(.system(size: 11, weight: .semibold))
              .foregroundStyle(.secondary)

            Text(title)
              .font(.caption.weight(.semibold))
              .foregroundStyle(.secondary)

            Image(systemName: "chevron.right")
              .font(.system(size: 9, weight: .bold))
              .foregroundStyle(.tertiary)
              .rotationEffect(.degrees(expanded ? 90 : 0))

            Spacer(minLength: 0)
          }
          .padding(.horizontal, 12)
          .padding(.vertical, 10)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(.secondary.opacity(0.08), in: .rect(cornerRadius: 12))
          .contentShape(.rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)

        if expanded {
          VStack(alignment: .leading, spacing: 6) {
            ForEach(items) { item in
              switch item {
              case .tool(let tool):
                ToolChip(tool: tool)
              case .terminal(let run):
                TerminalBlock(run: run)
              }
            }
          }
          .padding(.leading, 4)
          .transition(.opacity.combined(with: .move(edge: .top)))
        }
      }
    }
  }
}

struct ToolRow: View {
  let tools: [ToolUse]

  var body: some View {
    ToolsDisclosure(tools: tools)
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
    if part.hasPrefix("+") { return .primary }
    if part.hasPrefix("−") || part.hasPrefix("-") { return .secondary }
    return .secondary.opacity(0.6)
  }
}
