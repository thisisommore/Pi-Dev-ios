//
//  SidebarView.swift
//  Pi Dev Mac
//

import AppKit
import SwiftUI

struct SidebarView: View {
    @Bindable var store: ChatStore

    /// Subtle gray selection (not system accent blue).
    private var selectionFill: Color {
        Color(nsColor: .unemphasizedSelectedContentBackgroundColor)
    }

    var body: some View {
        VStack(spacing: 0) {
            searchField
                .padding(.top, 2)
            sessionList
            Spacer(minLength: 0)
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .safeAreaPadding(.top, 0)
    }

    // MARK: - Search

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            TextField("Search chats", text: $store.searchText)
                .textFieldStyle(.plain)
                .font(.callout)
            if !store.searchText.isEmpty {
                Button {
                    store.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
    }

    // MARK: - List

    /// Outer gap before the selection background (right of the row pill).
    private let rowOuterTrailing: CGFloat = 0
    /// Outer gap on the left — +1 so it visually matches the right side.
    private let rowOuterLeading: CGFloat = 4
    /// Inner text padding inside the selection background.
    private let rowInnerPadding: CGFloat = 8

    private var sessionList: some View {
        // ScrollView instead of List — full control over side padding
        // (List on macOS forces a large leading inset before row backgrounds).
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2, pinnedViews: [.sectionHeaders]) {
                if store.searchText.isEmpty {
                    ForEach(store.sessionsByProject, id: \.project) { group in
                        Section {
                            ForEach(group.sessions) { session in
                                sessionRow(session)
                            }
                        } header: {
                            projectHeader(group.project)
                                .padding(.leading, 8)
                                .padding(.trailing, 0)
                                .padding(.top, 10)
                                .padding(.bottom, 0)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(nsColor: .controlBackgroundColor))
                        }
                    }
                } else {
                    Section {
                        ForEach(store.filteredSessions) { session in
                            sessionRow(session)
                        }
                    } header: {
                        sectionHeader("Results")
                            .padding(.leading, rowOuterLeading + rowInnerPadding)
                            .padding(.trailing, rowOuterTrailing + rowInnerPadding)
                            .padding(.top, 10)
                            .padding(.bottom, 4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(nsColor: .controlBackgroundColor))
                    }
                }
            }
            .padding(.leading, rowOuterLeading)
            .padding(.trailing, rowOuterTrailing)
            .padding(.bottom, 8)
            .background(ScrollViewStyleConfigurator())
        }
        .contentMargins(.trailing, -8, for: .scrollContent)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
    }

    /// Project / folder section header with a new-chat control on the trailing edge.
    private func projectHeader(_ project: String) -> some View {
        HStack(spacing: 6) {
            Text(project)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(nil)
                .lineLimit(1)

            Spacer(minLength: 4)

            Button {
                store.newChat(in: project)
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("New chat in \(project)")
            .accessibilityLabel("New chat in \(project)")
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(nil)
    }

    private func sessionRow(_ session: ChatSession) -> some View {
        let isSelected = store.selectedSessionID == session.id

        return Button {
            store.select(session)
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(session.title)
                        .font(.callout.weight(.medium))
                        .lineLimit(1)
                        .foregroundStyle(.primary)

                    Text(session.preview.isEmpty ? "No messages yet" : session.preview)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                Text(session.relativeUpdated)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
            .padding(.horizontal, rowInnerPadding)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? selectionFill : Color.clear)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                store.delete(session)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Om More")
                    .font(.caption.weight(.semibold))
                Text("Local · Free")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "ellipsis.circle")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .overlay(alignment: .top) {
            Divider()
        }
    }
}

/// Configures the backing `NSScrollView` to use a thin, dark overlay scroller.
private struct ScrollViewStyleConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.isHidden = true
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let scrollView = nsView.firstAncestor(ofType: NSScrollView.self) else { return }
            scrollView.scrollerStyle = .overlay
            scrollView.automaticallyAdjustsContentInsets = false
            scrollView.contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
            scrollView.scrollerInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: -4)
            if !(scrollView.verticalScroller is SidebarScroller) {
                let scroller = SidebarScroller()
                scroller.controlSize = .small
                scrollView.verticalScroller = scroller
            }
        }
    }
}

/// A darker overlay-style vertical scroller that brightens on hover.
private final class SidebarScroller: NSScroller {
    private var trackingArea: NSTrackingArea?
    private var isHovered = false

    override class func scrollerWidth(for controlSize: NSControl.ControlSize, scrollerStyle: NSScroller.Style) -> CGFloat {
        if controlSize == .small {
            return 8
        }
        return super.scrollerWidth(for: controlSize, scrollerStyle: scrollerStyle)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp],
            owner: self
        )
        addTrackingArea(area)
        self.trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        setNeedsDisplay()
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        setNeedsDisplay()
    }

    override func drawKnob() {
        let knobRect = rect(for: .knob)
        let color: NSColor
        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        if isHovered {
            color = NSColor(white: 0.90, alpha: isDark ? 0.85 : 0.70)
        } else if isDark {
            color = NSColor(white: 0.50, alpha: 0.70)
        } else {
            color = NSColor(white: 0.45, alpha: 0.55)
        }
        color.setFill()
        NSBezierPath(roundedRect: knobRect.insetBy(dx: 0, dy: 0), xRadius: 2, yRadius: 2).fill()
    }

    override func drawKnobSlot(in slotRect: NSRect, highlight: Bool) {
        // Keep the slot transparent so only the floating knob is visible.
    }
}

private extension NSView {
    func firstAncestor<T: NSView>(ofType type: T.Type) -> T? {
        var current: NSView? = self.superview
        while let view = current {
            if let match = view as? T { return match }
            current = view.superview
        }
        return nil
    }
}

#Preview {
    SidebarView(store: ChatStore())
        .frame(width: 280, height: 640)
        .background(Color(nsColor: .controlBackgroundColor))
}
