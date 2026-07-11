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

    func makeNSView(context: Context) -> ResizeHandleView {
        ResizeHandleView(delegate: context.coordinator)
    }

    func updateNSView(_ nsView: ResizeHandleView, context: Context) {
        nsView.delegate = context.coordinator
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

    init(delegate: ResizeHandleViewDelegate) {
        self.delegate = delegate
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { nil }

    /// Prevent the window from interpreting a press here as a window drag.
    override var mouseDownCanMoveWindow: Bool { false }

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
