//
//  AICodeChat+Sidebar.swift
//  Pi Dev
//

import SwiftUI

struct Sidebar: View {
  @Bindable var store: SidebarStore

  var body: some View {
    ZStack {
      Color(.systemBackground)
        .ignoresSafeArea()
      LinearGradient(
        colors: [appColor.opacity(0.08), .clear, .teal.opacity(0.06)],
        startPoint: .topLeading, endPoint: .bottomTrailing
      )
      .ignoresSafeArea()

      VStack(spacing: 0) {
        HStack {
          Text("πcode")
            .font(.largeTitle)
          Spacer()
          Button {
            store.newChat()
          } label: {
            Image(systemName: "magnifyingglass")
              .font(.system(size: 16, weight: .light))
              .frame(width: 36, height: 36)
          }
          .buttonStyle(.plain)
          .glassEffect(.regular.interactive(), in: .circle)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)

        ScrollView {
          LazyVStack(spacing: 8) {
            ForEach(store.filteredChats) { chat in
              Button {
                store.select(chatId: chat.id)
              } label: {
                HStack(spacing: 10) {
                  Text(chat.chatTitle)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                  if store.selectedChatId == chat.id {
                    Circle()
                      .fill(.primary)
                      .frame(width: 6, height: 6)
                  }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 18)
              }
              .buttonStyle(.plain)
              .background {
                if store.selectedChatId == chat.id {
                  Color.clear
                    .glassEffect(.regular, in: .rect(cornerRadius: 12))
                }
              }
              .contextMenu {
                Button(role: .destructive) {
                  store.delete(chatId: chat.id)
                } label: {
                  Label("Delete", systemImage: "trash")
                }
              }
            }
          }
          .padding(.horizontal, 16)
          .padding(.top, 4)
        }

        Spacer(minLength: 0)
      }
    }
  }
}
