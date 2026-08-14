//
//  Theme.swift
//  Pi Dev Mac
//

import AppKit
import SwiftUI

enum MacTheme {
    private static func isDark(_ appearance: NSAppearance) -> Bool {
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    /// Chat canvas — white in light, near-black `#09090b` in dark.
    static let canvas = NSColor(name: nil) { appearance in
        isDark(appearance)
            ? NSColor(red: 0.035, green: 0.035, blue: 0.043, alpha: 1)
            : NSColor.white
    }

    /// Sidebar — light gray in light, slightly lifted black in dark.
    static let sidebar = NSColor(name: nil) { appearance in
        isDark(appearance)
            ? NSColor(white: 0.07, alpha: 1)
            : NSColor(white: 0.96, alpha: 1)
    }

    static let divider = NSColor(name: nil) { appearance in
        isDark(appearance)
            ? NSColor(white: 0.18, alpha: 1)
            : NSColor(white: 0.86, alpha: 1)
    }
}

let appCanvas = Color(nsColor: MacTheme.canvas)
let appSidebar = Color(nsColor: MacTheme.sidebar)

/// Ink fill — near-black in light, white in dark (matches pi logo).
let appColor = Color(nsColor: NSColor(name: nil) { appearance in
    appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        ? NSColor.white
        : NSColor(red: 0.035, green: 0.035, blue: 0.043, alpha: 1)
})

/// Body text / icons.
let appLabel = Color(nsColor: NSColor(name: nil) { appearance in
    appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        ? NSColor(white: 0.90, alpha: 1)
        : NSColor(white: 0.14, alpha: 1)
})

/// Header / chrome icons.
let appIcon = Color(nsColor: NSColor(name: nil) { appearance in
    appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        ? NSColor(white: 0.72, alpha: 1)
        : NSColor(white: 0.38, alpha: 1)
})

/// Text / icons painted on solid ink fills.
let appOnInk = Color(nsColor: NSColor(name: nil) { appearance in
    appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        ? NSColor(red: 0.035, green: 0.035, blue: 0.043, alpha: 1)
        : NSColor.white
})

extension Int {
    var compactUS: String {
        formatted(.number.notation(.compactName).locale(Locale(identifier: "en_US")))
    }
}
