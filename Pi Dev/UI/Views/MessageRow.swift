//
//  MessageRow.swift
//  Pi Dev
//

import SwiftUI

struct MessageRow: View {
  let message: ChatMessage
  @Bindable var store: ChatStore

  private var isBeingEdited: Bool { store.editingMessageId == message.id }
  private var isBlurred: Bool { store.editingMessageId != nil && !isBeingEdited }

  var body: some View {
    Group {
      switch message.role {
      case .user:      UserBubble(message: message, store: store)
      case .assistant: AssistantMessage(message: message, store: store)
      }
    }
    .scaleEffect(isBeingEdited ? 1.04 : 1)
    .blur(radius: isBlurred ? 10 : 0)
    .opacity(isBlurred ? 0.4 : 1)
    .allowsHitTesting(!isBlurred)
    .animation(.snappy, value: store.editingMessageId)
  }
}
