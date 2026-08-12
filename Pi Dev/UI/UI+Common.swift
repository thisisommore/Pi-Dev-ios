//
//  UI+Common.swift
//  Pi Dev
//

import SwiftUI
import UIKit

// MARK: - pi.dev monochrome palette
//
// From https://pi.dev/style.css:
//   --pi-logo-color (light): #09090b
//   --pi-logo-color (dark):  #ffffff
//   --black / --white plus neutral grays for surfaces
//
// App chrome is black / white / gray only.

/// Ink fill — near-black in light, white in dark (matches pi logo).
let appColor = Color(uiColor: UIColor { traits in
  traits.userInterfaceStyle == .dark
    ? UIColor.white
    : UIColor(red: 0.035, green: 0.035, blue: 0.043, alpha: 1) // #09090b
})

/// Text / icons painted on solid ink fills.
let appOnInk = Color(uiColor: UIColor { traits in
  traits.userInterfaceStyle == .dark
    ? UIColor(red: 0.035, green: 0.035, blue: 0.043, alpha: 1) // #09090b
    : UIColor.white
})

extension Int {
  /// Formats the integer using US-style compact notation (K, M, B, T),
  /// ignoring the user's locale so it never shows regional suffixes like L/C.
  var compactUS: String {
    formatted(.number.notation(.compactName).locale(Locale(identifier: "en_US")))
  }
}
