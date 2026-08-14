//
//  ContextGauge.swift
//  Pi Dev Mac
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
                Label("\(remaining.compactUS) tokens left", systemImage: "gauge.open.with.lines.needle.33percent")
                Label("\(used.compactUS) of \(window.compactUS) used", systemImage: "chart.pie")
            }
        } label: {
            ZStack {
                Circle()
                    .stroke(.quaternary, lineWidth: 2.5)
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(appIcon, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
        }
        .buttonStyle(.plain)
        .help("Context remaining \(Int((1 - fraction) * 100)) percent")
    }
}
