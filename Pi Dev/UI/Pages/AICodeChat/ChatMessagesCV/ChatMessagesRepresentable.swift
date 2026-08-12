//
//  ChatMessagesRepresentable.swift
//  Pi Dev
//
//  UIViewControllerRepresentable wrapper for the custom UICollectionView chat list.
//  Mirrors Haven's ChatMessages (ChatMessages+Representable.swift) on iOS 17.2.
//

import SwiftUI

struct ChatMessagesView: UIViewControllerRepresentable {
  @Bindable var store: ChatStore

  func makeUIViewController(context: Context) -> ChatMessagesVC {
    ChatMessagesVC(store: store)
  }

  func updateUIViewController(_ uiViewController: ChatMessagesVC, context: Context) {
    uiViewController.store = store
    uiViewController.applySnapshot(animated: true)
  }
}
