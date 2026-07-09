//
//  AssistantMessage.swift
//  Pi Dev
//

import SwiftUI

struct AssistantMessage: View {
  let message: ChatMessage
  @Bindable var store: ChatStore

  private var hasContent: Bool {
    !message.text.isEmpty || message.thinking != nil || !message.tools.isEmpty
  }

  private var attributedText: AttributedString {
    (try? AttributedString(
      markdown: message.text,
      options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
    )) ?? AttributedString(message.text)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      if message.isStreaming && !hasContent {
        LoadingDots()
      }

      if let thinking = message.thinking {
        ThinkingBlock(thinking: thinking)
      }
      if !message.tools.isEmpty {
        ToolRow(tools: message.tools)
          .padding(.top, message.thinking != nil ? 2 : 0)
      }

      Text(attributedText)
        .font(.callout)
        .lineSpacing(3)
        .textSelection(.enabled)

      if let code = message.code {
        CodeBlock(language: code.language, source: code.source)
      }

      if !message.isStreaming && message.id == store.messages.last?.id && store.generatingMessageId == nil {
        HStack(spacing: 10) {
          Text("\(message.tokens.formatted(.number.notation(.compactName))) tok")
          CopyButton(message: message)
          RetryButton(message: message, store: store)
        }
        .font(.caption2)
        .foregroundStyle(.tertiary)
        .padding(.top, 2)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 2)
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

private struct CopyButton: View {
  let message: ChatMessage
  @State private var copied = false

  var body: some View {
    Button {
      UIPasteboard.general.string = message.text
      copied = true
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
        copied = false
      }
    } label: {
      Image(systemName: copied ? "checkmark" : "doc.on.doc")
        .font(.system(size: 12))
    }
    .buttonStyle(.plain)
    .help("Copy response")
  }
}

private struct LoadingDots: View {
  @State private var phase = false

  var body: some View {
    HStack(spacing: 6) {
      HStack(spacing: 3) {
        ForEach(0..<3) { i in
          Circle()
            .fill(.secondary)
            .frame(width: 5, height: 5)
            .opacity(phase ? 1 : 0.25)
            .animation(.easeInOut(duration: 0.6).repeatForever().delay(Double(i) * 0.18),
                       value: phase)
        }
      }
      Text("Working")
        .font(.caption.weight(.medium))
        .foregroundStyle(.secondary)
    }
    .padding(.top, 2)
    .onAppear { phase = true }
  }
}
