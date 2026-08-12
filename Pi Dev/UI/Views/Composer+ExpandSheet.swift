//
//  Composer+ExpandSheet.swift
//  Pi Dev
//

import SwiftUI
import Combine

struct ComposerExpandSheet: View {
  @Binding var text: String

  @Environment(\.dismiss) private var dismiss

  @FocusState private var focused: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Capsule()
        .fill(.tertiary)
        .frame(width: 36, height: 5)
        .frame(maxWidth: .infinity)
        .padding(.top, 10)

      HStack {
        Text("Message")
          .font(.title3.weight(.bold))
        Spacer()
        Button("Done") {
          self.focused = false
          self.dismiss()
        }
        .font(.body.weight(.semibold))
        .foregroundStyle(appLabel)
      }
      .padding(.horizontal, 20)
      .padding(.top, 12)
      .padding(.bottom, 8)

      TextEditor(text: self.$text)
        .font(.body)
        .scrollContentBackground(.hidden)
        .tint(.primary)
        .focused(self.$focused)
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    .onAppear { self.focused = true }
  }
}
