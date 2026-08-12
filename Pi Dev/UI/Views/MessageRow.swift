//
//  MessageRow.swift
//  Pi Dev
//

import SwiftUI
import Combine

struct MessageRow: View {
  @Bindable var store: ChatStore
  let messageId: UUID

  private var message: ChatMessage? {
    store.messages.first { $0.id == messageId }
  }

  private var isBeingEdited: Bool { store.editingMessageId == messageId }
  private var isBlurred: Bool { store.editingMessageId != nil && !isBeingEdited }

  var body: some View {
    Group {
      if let message {
        switch message.role {
        case .user:      UserBubble(store: store, message: message)
        case .assistant: AssistantMessage(store: store, message: message)
        }
      }
    }
    .scaleEffect(isBeingEdited ? 1.04 : 1)
    .blur(radius: isBlurred ? 10 : 0)
    .opacity(isBlurred ? 0.4 : 1)
    .allowsHitTesting(!isBlurred)
    .animation(.snappy, value: store.editingMessageId)
  }
}
