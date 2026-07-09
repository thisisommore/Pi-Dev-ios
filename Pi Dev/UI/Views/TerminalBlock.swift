//
//  TerminalBlock.swift
//  Pi Dev
//

import SwiftUI

struct TerminalBlock: View {
  let run: TerminalRun
  @State private var expanded = true

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Button {
        withAnimation(.snappy) { expanded.toggle() }
      } label: {
        HStack(spacing: 0) {
          Text(run.command)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .lineLimit(1)
          Spacer()
          Image(systemName: run.exitCode == 0 ? "checkmark" : "xmark")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(run.exitCode == 0 ? .green : .red)
          Image(systemName: "chevron.down")
            .font(.system(size: 9, weight: .bold))
            .rotationEffect(.degrees(expanded ? 180 : 0))
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(.rect)
      }
      .buttonStyle(.plain)

      if expanded {
        Divider().opacity(0.4)
        Text(run.output)
          .font(.system(size: 11, design: .monospaced))
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(12)
          .transition(.opacity)
      }
    }
    .background(.secondary.opacity(0.12), in: .rect(cornerRadius: 16))
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .strokeBorder(.secondary.opacity(0.2), lineWidth: 1)
    )
  }
}
