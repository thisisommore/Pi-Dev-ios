//
//  TerminalBlock.swift
//  Pi Dev
//

import SwiftUI

struct TerminalBlock: View {
  let run: TerminalRun
  @State private var expanded = true

  private var succeeded: Bool { run.exitCode == 0 }

  private static let maxCommandLines = 3
  private static let maxOutputLines = 4

  /// Truncates by line count, returning the visible text and how many
  /// lines were hidden.
  private func truncateLines(_ string: String, maxLines: Int) -> (text: String, hiddenLines: Int) {
    let lines = string.components(separatedBy: "\n")
    guard lines.count > maxLines else { return (string, 0) }
    return (lines.prefix(maxLines).joined(separator: "\n"), lines.count - maxLines)
  }

  private var truncatedCommand: (text: String, hiddenLines: Int) {
    truncateLines(run.command, maxLines: Self.maxCommandLines)
  }

  private var truncatedOutput: (text: String, hiddenLines: Int) {
    truncateLines(run.output, maxLines: Self.maxOutputLines)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Button {
        withAnimation(.snappy) { expanded.toggle() }
      } label: {
        HStack(alignment: .top, spacing: 8) {
          Image(systemName: "terminal")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: 18)
            .padding(.top, 1)

          Text(truncatedCommand.text + (truncatedCommand.hiddenLines > 0 ? "\n…" : ""))
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(.primary)
            .lineLimit(expanded ? Self.maxCommandLines + 1 : 1)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)

          Image(systemName: succeeded ? "checkmark.circle.fill" : "xmark.circle.fill")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(succeeded ? .green : .red)
            .padding(.top, 1)

          Image(systemName: "chevron.down")
            .font(.system(size: 9, weight: .bold))
            .rotationEffect(.degrees(expanded ? 180 : 0))
            .foregroundStyle(.tertiary)
            .padding(.top, 2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(.rect)
      }
      .buttonStyle(.plain)

      if expanded {
        Divider().opacity(0.35)

        ScrollView(.horizontal, showsIndicators: false) {
          Text(run.output.isEmpty ? "(no output)" : truncatedOutput.text)
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(run.output.isEmpty ? .tertiary : .secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .transition(.opacity.combined(with: .move(edge: .top)))

        if truncatedOutput.hiddenLines > 0 {
          Text("… \(truncatedOutput.hiddenLines) more lines")
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 12)
            .padding(.bottom, 10)
        }

        if !succeeded {
          HStack(spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill")
              .font(.system(size: 9))
            Text("exit \(run.exitCode)")
              .font(.system(size: 10, weight: .semibold, design: .monospaced))
          }
          .foregroundStyle(.red.opacity(0.9))
          .padding(.horizontal, 12)
          .padding(.bottom, 10)
        }
      }
    }
    .background(.secondary.opacity(0.10), in: .rect(cornerRadius: 14))
    .overlay(
      RoundedRectangle(cornerRadius: 14)
        .strokeBorder(.secondary.opacity(0.18), lineWidth: 1)
    )
  }
}
