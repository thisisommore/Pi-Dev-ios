//
//  ChatMessages+Representable.swift
//  Pi Dev
//

import SwiftUI
import Combine

struct ChatMessagesView: UIViewControllerRepresentable {
  @Bindable var store: ChatStore
  @Binding var showSidebar: Bool
  @Binding var showModelSheet: Bool
  var onNewChat: () -> Void

  func makeUIViewController(context: Context) -> ChatMessagesVC {
    ChatMessagesVC(store: store)
  }

  func updateUIViewController(_ uiViewController: ChatMessagesVC, context: Context) {
    uiViewController.store = store
    uiViewController.installHeader(
      Header(
        store: store,
        showModelSheet: $showModelSheet,
        showSidebar: $showSidebar,
        onNewChat: onNewChat
      )
    )
    uiViewController.syncList()
  }
}
