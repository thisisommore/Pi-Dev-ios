//
//  MessageRow.swift
//  Pi Dev
//

import SwiftUI

struct MessageRow: View {
  let messageId: UUID
  @Bindable var store: ChatStore

  private var message: ChatMessage? {
    store.messages.first { $0.id == messageId }
  }

  private var isBeingEdited: Bool { store.editingMessageId == messageId }
  private var isBlurred: Bool { store.editingMessageId != nil && !isBeingEdited }

  var body: some View {
    Group {
      if let message {
        switch message.role {
        case .user:      UserBubble(message: message, store: store)
        case .assistant: AssistantMessage(message: message, store: store)
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
