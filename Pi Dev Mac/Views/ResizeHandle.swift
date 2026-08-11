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
    /// When true, paint the left half with the detail background and the
    /// right half with the sidebar background (used for the right sidebar).
    var isRightSide: Bool = false
    /// Inverts the drag delta so the handle can resize a sidebar on the right edge.
    var inverted: Bool = false

    func makeNSView(context: Context) -> ResizeHandleView {
        ResizeHandleView(delegate: context.coordinator, lineWhite: lineWhite, isRightSide: isRightSide)
    }

    func updateNSView(_ nsView: ResizeHandleView, context: Context) {
        nsView.delegate = context.coordinator
        nsView.lineWhite = lineWhite
        nsView.isRightSide = isRightSide
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(width: $width, minWidth: minWidth, maxWidth: maxWidth, inverted: inverted)
    }

    final class Coordinator: ResizeHandleViewDelegate {
        @Binding var width: CGFloat
        let minWidth: CGFloat
        let maxWidth: CGFloat
        let inverted: Bool
        private var dragStartWidth: CGFloat = 0

        init(width: Binding<CGFloat>, minWidth: CGFloat, maxWidth: CGFloat, inverted: Bool = false) {
            self._width = width
            self.minWidth = minWidth
            self.maxWidth = maxWidth
            self.inverted = inverted
        }

        func resizeBegan() {
            dragStartWidth = width
        }

        func resizeChanged(delta: CGFloat) {
            let effectiveDelta = inverted ? -delta : delta
            let next = dragStartWidth + effectiveDelta
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
    var isRightSide: Bool

    init(delegate: ResizeHandleViewDelegate, lineWhite: CGFloat, isRightSide: Bool = false) {
        self.delegate = delegate
        self.lineWhite = lineWhite
        self.isRightSide = isRightSide
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { nil }

    /// Prevent the window from interpreting a press here as a window drag.
    override var mouseDownCanMoveWindow: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        // Paint the entire 8 pt handle so no underlying content shows through.
        // Fill the left and right halves with the adjacent column colors, then
        // draw the 1 pt divider line in the center.
        let midX = bounds.midX
        let leftRect = NSRect(x: 0, y: 0, width: midX, height: bounds.height)
        let rightRect = NSRect(x: midX, y: 0, width: bounds.width - midX, height: bounds.height)

        if isRightSide {
            NSColor.textBackgroundColor.setFill()
            leftRect.fill()
            NSColor.controlBackgroundColor.setFill()
            rightRect.fill()
        } else {
            NSColor.controlBackgroundColor.setFill()
            leftRect.fill()
            NSColor.textBackgroundColor.setFill()
            rightRect.fill()
        }

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
