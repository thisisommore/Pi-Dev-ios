//
//  UserBubble.swift
//  Pi Dev
//

import SwiftUI
import UIKit

struct UserBubble: View {
  let message: ChatMessage
  @Bindable var store: ChatStore

  private var attributedText: AttributedString {
    (try? AttributedString(markdown: message.text)) ?? AttributedString(message.text)
  }

  var body: some View {
    HStack {
      Spacer(minLength: 56)
      Text(attributedText)
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
