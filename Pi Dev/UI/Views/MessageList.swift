//
//  MessageList.swift
//  Pi Dev
//

import SwiftUI

struct MessageList: View {
  @Bindable var store: ChatStore
  @Binding var showSidebar: Bool
  @Binding var showModelSheet: Bool
  var onNewChat: () -> Void

  var body: some View {
    if store.messages.isEmpty {
      EmptyChatView()
    } else {
      // Custom UICollectionView-based list — same approach as Haven's
      // ChatMessagesCV (iOS 17.2). Provides interactive keyboard dismiss,
      // preserveBottomOffset, scroll-to-bottom button, and near-bottom tracking.
      if #available(iOS 17.2, *) {
        ChatMessagesView(
          store: store,
          showSidebar: $showSidebar,
          showModelSheet: $showModelSheet,
          onNewChat: onNewChat
        )
        .ignoresSafeArea(.keyboard, edges: .bottom)
      } else {
        // Fallback for older OS — original SwiftUI ScrollView
        ScrollViewFallback(store: store)
      }
    }
  }
}

private struct ScrollViewFallback: View {
  @Bindable var store: ChatStore
  @State private var isNearBottom = true

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(spacing: 12) {
          ForEach(store.messages) { message in
            MessageRow(messageId: message.id, store: store)
              .id(message.id)
          }
          if store.isResponding {
            TypingIndicator(tint: appColor).id("typing")
          }
        }
        .padding(.horizontal, 16)
        .padding(.top, 68)
        .padding(.bottom, 12)
      }
      .frame(maxHeight: .infinity)
      .scrollDismissesKeyboard(.interactively)
      .onChange(of: store.messages.count) { oldCount, newCount in
        if oldCount == 0 && newCount > 0 { isNearBottom = true }
        guard isNearBottom else { return }
        withAnimation(.snappy) { proxy.scrollTo(store.messages.last?.id, anchor: .bottom) }
      }
      .onChange(of: store.messages.last?.text) {
        guard isNearBottom else { return }
        withAnimation(.snappy) { proxy.scrollTo(store.messages.last?.id, anchor: .bottom) }
      }
    }
  }
}
