//
//  UserBubble.swift
//  Pi Dev
//

import SwiftUI
import UIKit

struct UserBubble: View {
  let message: ChatMessage
  @Bindable var store: ChatStore

  var body: some View {
    HStack {
      Spacer(minLength: 56)
      Text(message.text)
        .font(.callout)
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .foregroundStyle(.white)
        .background(
          appColor,
          in: .rect(cornerRadius: 22)
        )
        .glassEffect(.clear, in: .rect(cornerRadius: 22))
        .contextMenu {
          Button {
            UIPasteboard.general.string = message.text
          } label: {
            Label("Copy", systemImage: "doc.on.doc")
          }
          Button {
            store.startEditing(message: message)
          } label: {
            Label("Edit", systemImage: "pencil")
          }
        }
    }
  }
}
