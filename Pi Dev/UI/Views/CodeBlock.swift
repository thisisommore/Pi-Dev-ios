//
//  CodeBlock.swift
//  Pi Dev
//

import SwiftUI

struct CodeBlock: View {
  let language: String
  let source: String

  private var languageLabel: String {
    let trimmed = language.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty || trimmed.contains(where: { $0.isWhitespace }) {
      return "TEXT"
    }
    return trimmed.uppercased()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        Text(languageLabel)
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
