//
//  AICodeChat.page.swift
//  Pi Dev
//

import SwiftUI
import Combine

struct AICodeChatView: View {
  @State private var sidebarStore: SidebarStore
  @State private var showSidebar = false
  @State private var showRemoteFolder = false

  init() {
    // Default arg evaluation is nonisolated; construct on the MainActor here instead.
    _sidebarStore = State(initialValue: SidebarStore())
  }

  init(sidebarStore: SidebarStore) {
    _sidebarStore = State(initialValue: sidebarStore)
  }

  var body: some View {
    GeometryReader { geometry in
      ZStack {
        Sidebar(store: sidebarStore, showRemoteFolder: $showRemoteFolder)
          .frame(width: geometry.size.width * 0.8)
          .frame(maxWidth: .infinity, alignment: .leading)

        ZStack {
          ChatDetailView(
            store: sidebarStore.activeChat,
            showSidebar: $showSidebar,
            onNewChat: {
              Task { @MainActor in
                await sidebarStore.newChat()
              }
            }
          )
          .frame(maxWidth: .infinity, maxHeight: .infinity)

          Color.black.opacity(showSidebar ? 0.25 : 0)
            .ignoresSafeArea()
            .contentShape(.rect)
            .onTapGesture {
              withAnimation(.snappy) {
                showSidebar = false
              }
            }
            .allowsHitTesting(showSidebar)
        }
        .offset(x: showSidebar ? geometry.size.width * 0.8 : 0)
        .animation(.snappy, value: showSidebar)
      }
      .onChange(of: sidebarStore.selectedSessionId) { _, _ in
        withAnimation(.snappy) {
          showSidebar = false
        }
      }
    }
    .sheet(isPresented: $showRemoteFolder) {
      RemoteFolderSheet()
        .presentationDetents([.large])
        .presentationBackground(.thinMaterial)
        .presentationCornerRadius(32)
    }
  }
}

#Preview("Dark") {
  Mock {
    AICodeChatView(sidebarStore: PreviewUtils.sidebarStore())
  }
  .preferredColorScheme(.dark)
}

#Preview("Light") {
  Mock {
    AICodeChatView(sidebarStore: PreviewUtils.sidebarStore())
  }
  .preferredColorScheme(.light)
}
