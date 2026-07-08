//
//  CodeBlock.swift
//  Pi Dev
//

import SwiftUI

struct CodeBlock: View {
  let language: String
  let source: String

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        Text(language.uppercased())
          .font(.system(size: 9, weight: .heavy))
          .foregroundStyle(.secondary)
        Spacer()
        Button {} label: {
          Label("Copy", systemImage: "doc.on.doc")
            .font(.system(size: 10, weight: .semibold))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)

      Divider().opacity(0.4)

      ScrollView(.horizontal, showsIndicators: false) {
        Text(source)
          .font(.system(size: 12, design: .monospaced))
          .padding(12)
          .textSelection(.enabled)
      }
    }
    .background(.secondary.opacity(0.12), in: .rect(cornerRadius: 16))
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .strokeBorder(.secondary.opacity(0.2), lineWidth: 1)
    )
  }
}
