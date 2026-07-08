//
//  TypingIndicator.swift
//  Pi Dev
//

import SwiftUI

struct TypingIndicator: View {
  let tint: Color
  @State private var phase = false

  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: "brain")
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(tint)
        .symbolEffect(.pulse, isActive: true)
      Text("Thinking…")
        .font(.caption.weight(.medium))
        .foregroundStyle(.secondary)
      HStack(spacing: 3) {
        ForEach(0..<3) { i in
          Circle()
            .fill(tint)
            .frame(width: 5, height: 5)
            .opacity(phase ? 1 : 0.25)
            .animation(.easeInOut(duration: 0.6).repeatForever().delay(Double(i) * 0.18),
                       value: phase)
        }
      }
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
    .glassEffect(.regular, in: .capsule)
    .frame(maxWidth: .infinity, alignment: .leading)
    .onAppear { phase = true }
  }
}
