//
//  AICodeChat+ChatDetail.swift
//  Pi Dev
//

import SwiftUI
import Combine

struct ChatDetailView: View {
  @Bindable var store: ChatStore

  @Binding var showSidebar: Bool
  var onNewChat: () -> Void = {}

  @State private var showModelSheet = false

  var body: some View {
    ZStack {
      Background()

      MessageList(
        store: store,
        showSidebar: $showSidebar,
        showModelSheet: $showModelSheet,
        onNewChat: onNewChat
      )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .overlay(alignment: .top) {
      if store.messages.isEmpty {
        Header(
          store: store,
          showModelSheet: $showModelSheet,
          showSidebar: $showSidebar,
          onNewChat: onNewChat
        )
        .safeAreaPadding(.top)
      }
    }
    .safeAreaInset(edge: .bottom, spacing: 0) {
      VStack(alignment: .leading, spacing: 0) {
        if store.editingMessageId != nil {
          Button {
            store.cancelEdit()
          } label: {
            Image(systemName: "xmark")
              .font(.system(size: 18, weight: .bold))
              .foregroundStyle(.gray)
              .frame(width: 44, height: 44)
              .background(.regularMaterial, in: .circle)
          }
          .buttonStyle(.plain)
          .padding(.leading, 16)
          .padding(.bottom, 8)
        }
        Composer(store: store, showModelSheet: $showModelSheet)
      }
    }
    .sheet(isPresented: $showModelSheet) {
      ModelSheet(store: store)
        .presentationDetents([.medium])
        .presentationBackground(.thinMaterial)
        .presentationCornerRadius(32)
    }
  }
}
