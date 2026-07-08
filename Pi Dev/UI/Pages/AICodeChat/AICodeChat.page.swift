//
//  AICodeChat.page.swift
//  Pi Dev
//

import SwiftUI

struct AICodeChatView: View {
  @State private var sidebarStore = SidebarStore()
  @State private var showSidebar = false

  var body: some View {
    GeometryReader { geometry in
      ZStack {
        Sidebar(store: sidebarStore)
          .frame(width: geometry.size.width * 0.8)
          .frame(maxWidth: .infinity, alignment: .leading)

        ZStack {
          if let selectedChat = sidebarStore.chats.first(where: { $0.id == sidebarStore.selectedChatId }) {
            ChatDetailView(store: selectedChat, showSidebar: $showSidebar)
              .frame(maxWidth: .infinity, maxHeight: .infinity)
          } else {
            EmptyChatView()
              .frame(maxWidth: .infinity, maxHeight: .infinity)
          }

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
      .onChange(of: sidebarStore.selectedChatId) { _, _ in
        withAnimation(.snappy) {
          showSidebar = false
        }
      }
    }
  }
}

#Preview {
  AICodeChatView()
    .preferredColorScheme(.dark)
}
