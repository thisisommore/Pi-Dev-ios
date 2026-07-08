//
//  ContextGauge.swift
//  Pi Dev
//

import SwiftUI

struct ContextGauge: View {
  let fraction: Double
  let used: Int
  let window: Int

  private var remaining: Int { max(0, window - used) }

  var body: some View {
    Menu {
      Section("Context window") {
        Label("\(remaining.formatted(.number.notation(.compactName))) tokens left", systemImage: "gauge.open.with.lines.needle.33percent")
        Label("\(used.formatted(.number.notation(.compactName))) of \(window.formatted(.number.notation(.compactName))) used", systemImage: "chart.pie")
      }
    } label: {
      ZStack {
        Circle()
          .stroke(.quaternary, lineWidth: 3.5)
        Circle()
          .trim(from: 0, to: fraction)
          .stroke(Color.primary.gradient, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
          .rotationEffect(.degrees(-90))
      }
      .padding(9)
      .animation(.snappy, value: fraction)
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Context remaining \(Int((1 - fraction) * 100)) percent")
  }
}
