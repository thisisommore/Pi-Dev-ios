//
//  WindowChrome.swift
//  Pi Dev Mac
//
//  Makes the title bar transparent and full-size so column
//  backgrounds can paint under the traffic lights.
//

import AppKit
import SwiftUI

/// Hooks the hosting `NSWindow` and enables a full-bleed content area.
struct WindowChrome: NSViewRepresentable {
    var titlebarAppearsTransparent: Bool = true
    var fullSizeContentView: Bool = true

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.isHidden = true
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            Self.apply(to: window, transparent: titlebarAppearsTransparent, fullSize: fullSizeContentView)
        }
    }

    static func apply(to window: NSWindow, transparent: Bool, fullSize: Bool) {
        window.titlebarAppearsTransparent = transparent
        window.titleVisibility = transparent ? .hidden : .visible
        if fullSize {
            window.styleMask.insert(.fullSizeContentView)
        } else {
            window.styleMask.remove(.fullSizeContentView)
        }
        // Keep the window base clear so our SwiftUI column fills show through.
        window.backgroundColor = .clear
        window.isOpaque = false
        // Traffic lights sit on the content; allow dragging from the titlebar region.
        window.isMovableByWindowBackground = true
    }
}

extension View {
    /// Applies transparent full-size title bar chrome on macOS.
    func fullBleedWindowChrome() -> some View {
        background(WindowChrome())
    }
}
