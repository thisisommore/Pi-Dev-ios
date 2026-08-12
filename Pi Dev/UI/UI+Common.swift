//
//  UI+Common.swift
//  Pi Dev
//

import SwiftUI

/// Brand indigo — richer than system blue, reads cleanly on light and dark.
let appColor = Color(red: 0.40, green: 0.38, blue: 0.95)

/// Soft violet used as a secondary ambient accent (backgrounds, glows).
let appAccentSecondary = Color(red: 0.58, green: 0.42, blue: 0.95)

/// Logo / CTA gradient: indigo → sky.
var appGradient: LinearGradient {
  LinearGradient(
    colors: [
      Color(red: 0.45, green: 0.40, blue: 0.98),
      Color(red: 0.32, green: 0.55, blue: 0.98),
    ],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
  )
}

extension Int {
  /// Formats the integer using US-style compact notation (K, M, B, T),
  /// ignoring the user's locale so it never shows regional suffixes like L/C.
  var compactUS: String {
    formatted(.number.notation(.compactName).locale(Locale(identifier: "en_US")))
  }
}
