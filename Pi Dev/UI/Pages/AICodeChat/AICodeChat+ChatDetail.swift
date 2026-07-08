//
//  AICodeChat+ChatDetail.swift
//  Pi Dev
//

import SwiftUI

struct ChatDetailView: View {
  @Bindable var store: ChatStore
  @State private var showModelSheet = false
  @Binding var showSidebar: Bool

  var body: some View {
    ZStack {
      Background()

      VStack(spacing: 0) {
        Header(store: store, showModelSheet: $showModelSheet, showSidebar: $showSidebar)
        MessageList(store: store)
      }
      .contentShape(.rect)
      .onTapGesture {
        store.cancelEditIfUnchanged()
      }
    }
    .safeAreaInset(edge: .bottom) {
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
