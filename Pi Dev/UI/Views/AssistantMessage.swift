//
//  AssistantMessage.swift
//  Pi Dev
//

import SwiftUI

struct AssistantMessage: View {
  let message: ChatMessage
  @Bindable var store: ChatStore

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      if let thinking = message.thinking {
        ThinkingBlock(thinking: thinking)
      }
      if !message.tools.isEmpty {
        ToolRow(tools: message.tools)
      }
      ForEach(message.terminal) { run in
        TerminalBlock(run: run)
      }

      Text(message.text)
        .font(.callout)
        .lineSpacing(3)
        .textSelection(.enabled)

      if let code = message.code {
        CodeBlock(language: code.language, source: code.source)
      }

      HStack(spacing: 10) {
        Text("\(message.tokens.formatted(.number.notation(.compactName))) tok")
        RetryButton(message: message, store: store)
      }
      .font(.caption2)
      .foregroundStyle(.tertiary)
      .padding(.top, 2)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 16)
  }
}

private struct RetryButton: View {
  let message: ChatMessage
  @Bindable var store: ChatStore

  var body: some View {
    Menu {
      Button {
        store.retry(from: message.id)
      } label: {
        Label("Retry", systemImage: "arrow.clockwise")
      }
      Button {
        store.retryWithDifferentSettings(from: message.id)
      } label: {
        Label("Retry with different settings", systemImage: "slider.horizontal.3")
      }
    } label: {
      Image(systemName: "arrow.clockwise")
        .font(.system(size: 12))
    }
    .buttonStyle(.plain)
  }
}
