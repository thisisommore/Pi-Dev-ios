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
        // Use the standard window background so transient transparent regions
        // (e.g., during the sidebar show/hide transition) never reveal the desktop.
        window.backgroundColor = .windowBackgroundColor
        window.isOpaque = true
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
