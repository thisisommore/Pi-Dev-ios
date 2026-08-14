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
            .overlay(alignment: .topLeading) {
                Text(store.selectedSession?.title ?? "Pi Dev")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(appLabel)
                    .lineLimit(1)
                    .padding(.leading, isSidebarVisible ? 16 : 110)
                    .padding(.trailing, 140)
                    .padding(.top, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 52, alignment: .leading)
                    .offset(y: -52)
                    .allowsHitTesting(false)
            }
            .background {
                Rectangle()
                    .fill(appCanvas)
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
        .sheet(isPresented: $store.showFolderPicker) {
            FolderPickerSheet { path in
                store.setWorkingDir(path)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .newChatRequested)) { _ in
            store.newChat()
        }
    }

    private var resizeHandle: some View {
        ResizeHandle(
            width: $sidebarWidth,
            minWidth: sidebarMin,
            maxWidth: sidebarMax,
            lineWhite: 0
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
            lineWhite: 0,
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
            .fill(appSidebar)
            .ignoresSafeArea()
    }
}

#Preview {
    ContentView()
        .frame(width: 1100, height: 720)
}
