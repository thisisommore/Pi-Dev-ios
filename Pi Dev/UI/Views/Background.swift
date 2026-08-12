//
//  Background.swift
//  Pi Dev
//

import SwiftUI

struct Background: View {
  var body: some View {
    ZStack {
      Color(.systemBackground)

      // Soft diagonal wash — indigo top-left, violet bottom-right.
      LinearGradient(
        colors: [
          appColor.opacity(0.10),
          .clear,
          appAccentSecondary.opacity(0.09),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )

      // Ambient glows (kept low so the field stays clean, not washed-out).
      Circle()
        .fill(appColor.opacity(0.16))
        .frame(width: 360)
        .blur(radius: 100)
        .offset(x: -130, y: -260)
      Circle()
        .fill(appAccentSecondary.opacity(0.12))
        .frame(width: 300)
        .blur(radius: 90)
        .offset(x: 140, y: 300)
    }
    .ignoresSafeArea()
  }
}
