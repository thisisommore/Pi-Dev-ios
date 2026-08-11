//
//  ContentView.swift
//  Pi Dev Mac
//

import AppKit
import SwiftUI

struct ContentView: View {
    @State private var store = ChatStore()
    @State private var sidebarWidth: CGFloat = 280
    @State private var isSidebarVisible = true
    @State private var changesSidebarWidth: CGFloat = 280
    @Environment(\.colorScheme) private var colorScheme

    private let sidebarMin: CGFloat = 220
    private let sidebarMax: CGFloat = 360
    private let changesSidebarMin: CGFloat = 220
    private let changesSidebarMax: CGFloat = 420

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

            if store.isChangesSidebarVisible {
                // Drag edge to resize the right sidebar
                rightResizeHandle
                    .transition(.opacity)

                // Right changes sidebar
                ChangesSidebarView(store: store)
                    .frame(width: changesSidebarWidth)
                    .frame(maxHeight: .infinity)
                    .background {
                        SidebarBackground()
                    }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.snappy(duration: 0.22), value: isSidebarVisible)
        .animation(.snappy(duration: 0.22), value: store.isChangesSidebarVisible)
        .frame(minWidth: 800, minHeight: 500)
        .fullBleedWindowChrome()
        .background(ChangesSidebarTitlebarButton(store: store))
        .onReceive(NotificationCenter.default.publisher(for: .newChatRequested)) { _ in
            store.newChat()
        }
    }

    private var resizeHandle: some View {
        ResizeHandle(
            width: $sidebarWidth,
            minWidth: sidebarMin,
            maxWidth: sidebarMax,
            lineWhite: colorScheme == .dark ? 0.20 : 0.86
        )
        .frame(width: 8)
        .frame(maxHeight: .infinity)
        .ignoresSafeArea()
        .zIndex(1)
    }

    private var rightResizeHandle: some View {
        ResizeHandle(
            width: $changesSidebarWidth,
            minWidth: changesSidebarMin,
            maxWidth: changesSidebarMax,
            lineWhite: colorScheme == .dark ? 0.20 : 0.86,
            isRightSide: true,
            inverted: true
        )
        .frame(width: 8)
        .frame(maxHeight: .infinity)
        .ignoresSafeArea()
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
