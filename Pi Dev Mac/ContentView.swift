//
//  ContentView.swift
//  Pi Dev Mac
//

import AppKit
import SwiftUI

struct ContentView: View {
    @State private var store = ChatStore()
    @State private var sidebarWidth: CGFloat = 280
    @State private var dragStartWidth: CGFloat = 280
    @State private var isResizing = false
    @State private var isSidebarVisible = true
    @Environment(\.colorScheme) private var colorScheme

    private let sidebarMin: CGFloat = 220
    private let sidebarMax: CGFloat = 360

    var body: some View {
        HStack(spacing: 0) {
            if isSidebarVisible {
                // Full-height sidebar — background paints under traffic lights.
                SidebarView(store: store)
                    .frame(width: sidebarWidth)
                    .frame(maxHeight: .infinity)
                    .background {
                        SidebarBackground()
                    }
                    .transition(.move(edge: .leading).combined(with: .opacity))

                // Drag edge to resize
                resizeHandle
                    .transition(.opacity)
            }

            // Detail column
            NavigationStack {
                ChatDetailView(store: store, isSidebarVisible: $isSidebarVisible)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                Rectangle()
                    .fill(Color(nsColor: .textBackgroundColor))
                    .ignoresSafeArea()
            }
        }
        .animation(.snappy(duration: 0.22), value: isSidebarVisible)
        .frame(minWidth: 800, minHeight: 500)
        .fullBleedWindowChrome()
        .onReceive(NotificationCenter.default.publisher(for: .newChatRequested)) { _ in
            store.newChat()
        }
    }

    private var resizeHandle: some View {
        Rectangle()
            .fill(Color(white: colorScheme == .dark ? 0.20 : 0.86))
            .frame(width: 1)
            .frame(maxHeight: .infinity)
            .ignoresSafeArea()
            .overlay {
                // Wider hit target for dragging
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 8)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 1)
                            .onChanged { value in
                                if !isResizing {
                                    isResizing = true
                                    dragStartWidth = sidebarWidth
                                }
                                let next = dragStartWidth + value.translation.width
                                sidebarWidth = min(sidebarMax, max(sidebarMin, next))
                            }
                            .onEnded { _ in
                                isResizing = false
                            }
                    )
                    .onHover { hovering in
                        if hovering {
                            NSCursor.resizeLeftRight.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
            }
            .zIndex(1)
    }
}

/// Solid sidebar surface that always extends under the title bar / traffic lights.
private struct SidebarBackground: View {
    var body: some View {
        Rectangle()
            .fill(Color(nsColor: .controlBackgroundColor))
            .ignoresSafeArea()
    }
}

#Preview {
    ContentView()
        .frame(width: 1100, height: 720)
}
