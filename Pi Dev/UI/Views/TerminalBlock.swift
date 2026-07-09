//
//  TerminalBlock.swift
//  Pi Dev
//

import SwiftUI

struct TerminalBlock: View {
  let run: TerminalRun
  @State private var expanded = true

  private var succeeded: Bool { run.exitCode == 0 }

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

          Text(run.command)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(.primary)
            .lineLimit(expanded ? 4 : 1)
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
          Text(run.output.isEmpty ? "(no output)" : run.output)
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(run.output.isEmpty ? .tertiary : .secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .transition(.opacity.combined(with: .move(edge: .top)))

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
