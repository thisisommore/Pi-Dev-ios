//
//  ResizeHandle.swift
//  Pi Dev Mac
//

import AppKit
import SwiftUI

/// An AppKit-based vertical resize handle.
///
/// SwiftUI `DragGesture` conflicts with `NSWindow.isMovableByWindowBackground`
/// because the window claims the drag before the gesture begins. Using an
/// `NSView` that returns `false` from `mouseDownCanMoveWindow` lets the view
/// handle the drag directly while the rest of the window stays draggable.
struct ResizeHandle: NSViewRepresentable {
    @Binding var width: CGFloat
    var minWidth: CGFloat
    var maxWidth: CGFloat
    var lineWhite: CGFloat

    func makeNSView(context: Context) -> ResizeHandleView {
        ResizeHandleView(delegate: context.coordinator, lineWhite: lineWhite)
    }

    func updateNSView(_ nsView: ResizeHandleView, context: Context) {
        nsView.delegate = context.coordinator
        nsView.lineWhite = lineWhite
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(width: $width, minWidth: minWidth, maxWidth: maxWidth)
    }

    final class Coordinator: ResizeHandleViewDelegate {
        @Binding var width: CGFloat
        let minWidth: CGFloat
        let maxWidth: CGFloat
        private var dragStartWidth: CGFloat = 0

        init(width: Binding<CGFloat>, minWidth: CGFloat, maxWidth: CGFloat) {
            self._width = width
            self.minWidth = minWidth
            self.maxWidth = maxWidth
        }

        func resizeBegan() {
            dragStartWidth = width
        }

        func resizeChanged(delta: CGFloat) {
            let next = dragStartWidth + delta
            width = min(maxWidth, max(minWidth, next))
        }
    }
}

protocol ResizeHandleViewDelegate: AnyObject {
    func resizeBegan()
    func resizeChanged(delta: CGFloat)
}

final class ResizeHandleView: NSView {
    weak var delegate: ResizeHandleViewDelegate?
    private var trackingArea: NSTrackingArea?
    private var dragStartX: CGFloat = 0
    private var isDragging = false
    private var cursorPushDepth = 0
    var lineWhite: CGFloat

    init(delegate: ResizeHandleViewDelegate, lineWhite: CGFloat) {
        self.delegate = delegate
        self.lineWhite = lineWhite
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { nil }

    /// Prevent the window from interpreting a press here as a window drag.
    override var mouseDownCanMoveWindow: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        // The window background is clear, so the entire 8 pt handle must be
        // painted to avoid seeing through to the desktop. Fill the left and
        // right halves with the adjacent column colors, then draw the 1 pt
        // divider line in the center.
        let midX = bounds.midX
        let leftRect = NSRect(x: 0, y: 0, width: midX, height: bounds.height)
        let rightRect = NSRect(x: midX, y: 0, width: bounds.width - midX, height: bounds.height)

        NSColor.controlBackgroundColor.setFill()
        leftRect.fill()

        NSColor.textBackgroundColor.setFill()
        rightRect.fill()

        let lineRect = NSRect(x: midX - 0.5, y: 0, width: 1, height: bounds.height)
        NSColor(white: lineWhite, alpha: 1.0).setFill()
        lineRect.fill()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow],
            owner: self
        )
        addTrackingArea(area)
        self.trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        pushResizeCursor()
    }

    override func mouseExited(with event: NSEvent) {
        if !isDragging {
            popResizeCursorIfNeeded()
        }
    }

    override func mouseDown(with event: NSEvent) {
        isDragging = true
        dragStartX = event.locationInWindow.x
        delegate?.resizeBegan()
    }

    override func mouseDragged(with event: NSEvent) {
        let delta = event.locationInWindow.x - dragStartX
        delegate?.resizeChanged(delta: delta)
    }

    override func mouseUp(with event: NSEvent) {
        isDragging = false
        popResizeCursorIfNeeded()
    }

    private func pushResizeCursor() {
        cursorPushDepth += 1
        NSCursor.resizeLeftRight.push()
    }

    private func popResizeCursorIfNeeded() {
        guard cursorPushDepth > 0 else { return }
        cursorPushDepth -= 1
        NSCursor.pop()
    }
}
