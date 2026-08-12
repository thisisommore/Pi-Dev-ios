//
//  Background.swift
//  Pi Dev
//

import SwiftUI

struct Background: View {
  var body: some View {
    ZStack {
      Color(.systemBackground)

      // Barely-there monochrome wash (pi.dev is mostly flat canvas).
      LinearGradient(
        colors: [
          Color.primary.opacity(0.04),
          .clear,
          Color.primary.opacity(0.03),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )

      Circle()
        .fill(Color.primary.opacity(0.04))
        .frame(width: 360)
        .blur(radius: 100)
        .offset(x: -130, y: -260)
      Circle()
        .fill(Color.primary.opacity(0.03))
        .frame(width: 300)
        .blur(radius: 90)
        .offset(x: 140, y: 300)
    }
    .ignoresSafeArea()
  }
}
