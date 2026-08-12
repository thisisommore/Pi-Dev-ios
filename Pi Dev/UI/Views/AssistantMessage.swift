//
//  AssistantMessage.swift
//  Pi Dev
//

import SwiftUI

struct AssistantMessage: View {
  let message: ChatMessage
  @Bindable var store: ChatStore

  private var hasContent: Bool {
    !message.text.isEmpty || message.thinking != nil || !message.tools.isEmpty || message.error != nil
      || !message.segments.isEmpty
  }

  private var attributedText: AttributedString {
    markdown(message.text)
  }

  /// Collapse consecutive tool/terminal segments into disclosure groups so text
  /// stays in order while tool noise folds under "N tools".
  private var displaySections: [AssistantDisplaySection] {
    var sections: [AssistantDisplaySection] = []
    var pending: [ToolsDisclosure.Item] = []

    func flushActivity() {
      guard !pending.isEmpty else { return }
      let id = pending[0].id
      sections.append(.activity(id: id, items: pending))
      pending = []
    }

    for segment in message.segments {
      switch segment {
      case .text(let id, let text):
        flushActivity()
        sections.append(.text(id: id, text: text))
      case .tool(let tool):
        pending.append(.tool(tool))
      case .terminal(let run):
        pending.append(.terminal(run))
      }
    }
    flushActivity()
    return sections
  }

  private func markdown(_ string: String) -> AttributedString {
    // Parse line by line so raw newlines are preserved exactly. Heading
    // markers are styled manually because SwiftUI's Text does not render
    // block-level markdown presentation intents.
    var result = AttributedString()
    var insideCodeFence = false
    for line in string.components(separatedBy: "\n") {
      if line.hasPrefix("```") {
        insideCodeFence.toggle()
      }
      var lineText = line
      var headingLevel = 0
      if !insideCodeFence,
         let match = line.range(of: #"^(#{1,6})\s+"#, options: .regularExpression) {
        headingLevel = line[match].count(where: { $0 == "#" })
        lineText = String(line[match.upperBound...])
      }
      var parsed = (try? AttributedString(
        markdown: lineText,
        options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
      )) ?? AttributedString(lineText)
      if headingLevel > 0 {
        parsed.font = headingLevel <= 2 ? Font.title3.bold() : Font.headline
      }
      result.append(parsed)
      result.append(AttributedString("\n"))
    }
    return result
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      if message.isStreaming && !hasContent {
        LoadingDots()
      }

      if let thinking = message.thinking {
        ThinkingBlock(thinking: thinking)
      }
      if !message.segments.isEmpty {
        ForEach(displaySections) { section in
          switch section {
          case .text(_, let text):
            Text(markdown(text))
              .font(.callout)
              .lineSpacing(3)
              .textSelection(.enabled)
          case .activity(_, let items):
            ToolsDisclosure(
              items: items,
              initiallyExpanded: message.isStreaming
            )
            .padding(.top, 2)
            .padding(.bottom, 2)
          }
        }
      } else {
        if !message.tools.isEmpty || !message.terminal.isEmpty {
          ToolsDisclosure(
            tools: message.tools,
            terminal: message.terminal,
            initiallyExpanded: message.isStreaming
          )
          .padding(.top, message.thinking != nil ? 2 : 0)
        }

        Text(attributedText)
          .font(.callout)
          .lineSpacing(3)
          .textSelection(.enabled)
      }

      if let error = message.error {
        ErrorBlock(error: error)
      }

      if let code = message.code {
        CodeBlock(language: code.language, source: code.source)
      }

      if !message.isStreaming && message.id == store.messages.last?.id && store.generatingMessageId == nil {
        HStack(spacing: 10) {
          Text("\(message.tokens.compactUS) tok")
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

private enum AssistantDisplaySection: Identifiable {
  case text(id: UUID, text: String)
  case activity(id: UUID, items: [ToolsDisclosure.Item])

  var id: UUID {
    switch self {
    case .text(let id, _), .activity(let id, _): return id
    }
  }
}

private struct ErrorBlock: View {
  let error: String

  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      Image(systemName: "exclamationmark.triangle.fill")
        .font(.caption)
      Text(error)
        .font(.callout)
        .lineSpacing(3)
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .foregroundStyle(.primary)
    .padding(10)
    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
    .padding(.top, 4)
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
