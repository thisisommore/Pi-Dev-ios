//
//  MessageList.swift
//  Pi Dev
//

import SwiftUI

struct MessageList: View {
  @Bindable var store: ChatStore
  @State private var isNearBottom = true

  var body: some View {
    if store.messages.isEmpty {
      EmptyChatView()
    } else {
      ScrollViewReader { proxy in
        ScrollView {
          LazyVStack(spacing: 12) {
            ForEach(store.messages) { message in
              MessageRow(message: message, store: store)
                .id(message.id)
                .transition(.asymmetric(
                  insertion: .move(edge: .bottom).combined(with: .opacity),
                  removal: .opacity))
            }
            if store.isResponding {
              TypingIndicator(tint: appColor)
                .id("typing")
                .transition(.opacity)
            }
          }
          .padding(.horizontal, 16)
          .padding(.top, 8)
          .padding(.bottom, 12)
        }
        .frame(maxHeight: .infinity)
        .scrollDismissesKeyboard(.interactively)
        .scrollEdgeEffectStyle(.soft, for: .all)
        .defaultScrollAnchor(.bottom)
        .onScrollGeometryChange(for: Bool.self, of: { geometry in
          let threshold: CGFloat = 80
          let visibleBottom = geometry.contentOffset.y + geometry.bounds.height
          return visibleBottom >= geometry.contentSize.height - threshold
        }) { _, newValue in
          isNearBottom = newValue
        }
        .onChange(of: store.messages.count) { oldCount, newCount in
          if oldCount == 0 && newCount > 0 {
            isNearBottom = true
          }
          guard isNearBottom else { return }
          withAnimation(.snappy) {
            proxy.scrollTo(store.messages.last?.id, anchor: .bottom)
          }
        }
        .onChange(of: store.messages.last?.text) {
          guard isNearBottom else { return }
          withAnimation(.snappy) {
            proxy.scrollTo(store.messages.last?.id, anchor: .bottom)
          }
        }
      }
    }
  }
}
