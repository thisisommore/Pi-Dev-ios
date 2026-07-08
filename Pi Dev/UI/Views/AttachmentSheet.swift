//
//  AttachmentSheet.swift
//  Pi Dev
//

import SwiftUI

struct AttachmentSheet: View {
  let title: String
  let content: String
  let monospaced: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Capsule()
        .fill(.tertiary)
        .frame(width: 36, height: 5)
        .frame(maxWidth: .infinity)
        .padding(.top, 10)

      Text(title)
        .font(.title3.weight(.bold))
        .lineLimit(1)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)

      ScrollView {
        Text(content)
          .font(monospaced ? .system(size: 12, design: .monospaced) : .callout)
          .foregroundStyle(.secondary)
          .lineSpacing(3)
          .padding(.horizontal, 20)
          .padding(.bottom, 20)
          .textSelection(.enabled)
      }
    }
  }
}
