//
//  Background.swift
//  Pi Dev
//

import SwiftUI

struct Background: View {
  var body: some View {
    ZStack {
      Color(.systemBackground)
      LinearGradient(
        colors: [appColor.opacity(0.16), .clear, .teal.opacity(0.12)],
        startPoint: .topLeading, endPoint: .bottomTrailing
      )
      Circle()
        .fill(appColor.opacity(0.14))
        .frame(width: 380)
        .blur(radius: 110)
        .offset(x: -140, y: -280)
      Circle()
        .fill(.teal.opacity(0.12))
        .frame(width: 320)
        .blur(radius: 100)
        .offset(x: 150, y: 320)
    }
    .ignoresSafeArea()
  }
}
