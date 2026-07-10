//
//  UI+Common.swift
//  Pi Dev
//

import SwiftUI

let appColor = Color.blue

extension Int {
  /// Formats the integer using US-style compact notation (K, M, B, T),
  /// ignoring the user's locale so it never shows regional suffixes like L/C.
  var compactUS: String {
    formatted(.number.notation(.compactName).locale(Locale(identifier: "en_US")))
  }
}
