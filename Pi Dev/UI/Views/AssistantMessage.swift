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

  // MARK: - Table-aware block parsing (iOS fix)

  private func inlineAttributed(_ string: String, headingLevel: Int = 0) -> AttributedString {
    var parsed = (try? AttributedString(
      markdown: string,
      options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
    )) ?? AttributedString(string)
    if headingLevel > 0 {
      parsed.font = headingLevel <= 2 ? Font.title3.bold() : Font.headline
    }
    return parsed
  }

  private func splitTableRow(_ line: String) -> [String] {
    var s = line.trimmingCharacters(in: .whitespaces)
    if s.hasPrefix("|") { s.removeFirst() }
    if s.hasSuffix("|") { s.removeLast() }
    return s.split(separator: "|", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }
  }

  private func parseAlignment(_ cell: String) -> TableAlignment {
    let c = cell.trimmingCharacters(in: .whitespaces)
    let hasLeft = c.hasPrefix(":")
    let hasRight = c.hasSuffix(":")
    if hasLeft && hasRight { return .center }
    if hasRight { return .right }
    return .left
  }

  private func isTableSeparator(_ line: String) -> Bool {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    if trimmed.isEmpty { return false }
    // Must contain at least --- pattern
    if !trimmed.contains("---") && !trimmed.contains(":--") && !trimmed.contains("--:") { return false }
    let allowed = CharacterSet(charactersIn: "|-: ")
    if trimmed.unicodeScalars.contains(where: { !allowed.contains($0) }) { return false }
    let cells = splitTableRow(line)
    if cells.isEmpty { return false }
    for cell in cells {
      let c = cell.trimmingCharacters(in: .whitespaces)
      if c.isEmpty { continue }
      if c.range(of: #"^:?-+:?$"#, options: .regularExpression) == nil { return false }
    }
    return true
  }

  private func parseBlocks(_ text: String) -> [MarkdownBlock] {
    var blocks: [MarkdownBlock] = []
    let lines = text.components(separatedBy: "\n")
    var i = 0
    var insideCodeFence = false
    while i < lines.count {
      let line = lines[i]
      if line.hasPrefix("```") {
        insideCodeFence.toggle()
        // Render fence line itself as paragraph (preserves original inline behavior)
        blocks.append(.paragraph(id: UUID(), attributed: inlineAttributed(line)))
        i += 1
        continue
      }
      if insideCodeFence {
        blocks.append(.paragraph(id: UUID(), attributed: inlineAttributed(line)))
        i += 1
        continue
      }
      // Table detection: header + separator
      if line.contains("|"), i + 1 < lines.count, isTableSeparator(lines[i + 1]) {
        let headers = splitTableRow(line)
        let alignments = splitTableRow(lines[i + 1]).map { parseAlignment($0) }
        var rows: [[String]] = []
        var j = i + 2
        while j < lines.count {
          let rowLine = lines[j]
          if rowLine.trimmingCharacters(in: .whitespaces).isEmpty { break }
          if !rowLine.contains("|") { break }
          if isTableSeparator(rowLine) { break }
          rows.append(splitTableRow(rowLine))
          j += 1
        }
        if !headers.isEmpty {
          let table = MarkdownTable(headers: headers, alignments: alignments, rows: rows)
          blocks.append(.table(table))
          i = j
          continue
        }
      }
      var lineText = line
      var headingLevel = 0
      if let match = line.range(of: #"^(#{1,6})\s+"#, options: .regularExpression) {
        headingLevel = line[match].count(where: { $0 == "#" })
        lineText = String(line[match.upperBound...])
      }
      if lineText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        i += 1
        continue
      }
      let attributed = inlineAttributed(lineText, headingLevel: headingLevel)
      if headingLevel > 0 {
        blocks.append(.heading(id: UUID(), level: headingLevel, attributed: attributed))
      } else {
        blocks.append(.paragraph(id: UUID(), attributed: attributed))
      }
      i += 1
    }
    return blocks
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
            VStack(alignment: .leading, spacing: 8) {
              ForEach(parseBlocks(text)) { block in
                switch block {
                case .paragraph(_, let attributed):
                  Text(attributed)
                    .font(.subheadline)
                    .lineSpacing(3)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                case .heading(_, _, let attributed):
                  Text(attributed)
                    .lineSpacing(3)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                case .table(let table):
                  MarkdownTableView(table: table)
                }
              }
            }
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

        VStack(alignment: .leading, spacing: 8) {
          ForEach(parseBlocks(message.text)) { block in
            switch block {
            case .paragraph(_, let attributed):
              Text(attributed)
                .font(.subheadline)
                .lineSpacing(3)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            case .heading(_, _, let attributed):
              Text(attributed)
                .lineSpacing(3)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            case .table(let table):
              MarkdownTableView(table: table)
            }
          }
        }
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

// MARK: - Markdown table support (iOS only)

private enum TableAlignment {
  case left, center, right
}

private struct MarkdownTable: Identifiable {
  let id = UUID()
  let headers: [String]
  let alignments: [TableAlignment]
  let rows: [[String]]
}

private enum MarkdownBlock: Identifiable {
  case paragraph(id: UUID, attributed: AttributedString)
  case heading(id: UUID, level: Int, attributed: AttributedString)
  case table(MarkdownTable)

  var id: UUID {
    switch self {
    case .paragraph(let id, _): return id
    case .heading(let id, _, _): return id
    case .table(let t): return t.id
    }
  }
}

private struct MarkdownTableView: View {
  let table: MarkdownTable

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 0) {
        ForEach(Array(table.headers.enumerated()), id: \.offset) { idx, header in
          Text(inline(header))
            .font(.caption.weight(.semibold))
            .lineSpacing(2)
            .multilineTextAlignment(alignmentFor(idx))
            .frame(maxWidth: .infinity, alignment: frameAlignmentFor(idx))
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .textSelection(.enabled)
          if idx < table.headers.count - 1 {
            Divider()
          }
        }
      }
      .background(Color.primary.opacity(0.06))
      Divider()
      ForEach(Array(table.rows.enumerated()), id: \.offset) { rowIdx, row in
        HStack(spacing: 0) {
          ForEach(0..<table.headers.count, id: \.self) { colIdx in
            let cell = colIdx < row.count ? row[colIdx] : ""
            Text(inline(cell))
              .font(.caption)
              .lineSpacing(2)
              .multilineTextAlignment(alignmentFor(colIdx))
              .frame(maxWidth: .infinity, alignment: frameAlignmentFor(colIdx))
              .padding(.horizontal, 8)
              .padding(.vertical, 8)
              .textSelection(.enabled)
            if colIdx < table.headers.count - 1 {
              Divider()
            }
          }
        }
        .background(rowIdx % 2 == 1 ? Color.primary.opacity(0.03) : Color.clear)
        if rowIdx < table.rows.count - 1 {
          Divider().opacity(0.5)
        }
      }
    }
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .padding(.vertical, 4)
    .fixedSize(horizontal: false, vertical: true)
  }

  private func inline(_ string: String) -> AttributedString {
    (try? AttributedString(
      markdown: string,
      options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
    )) ?? AttributedString(string)
  }

  private func alignmentFor(_ idx: Int) -> TextAlignment {
    guard idx < table.alignments.count else { return .leading }
    switch table.alignments[idx] {
    case .left: return .leading
    case .center: return .center
    case .right: return .trailing
    }
  }

  private func frameAlignmentFor(_ idx: Int) -> Alignment {
    guard idx < table.alignments.count else { return .leading }
    switch table.alignments[idx] {
    case .left: return .leading
    case .center: return .center
    case .right: return .trailing
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
    .foregroundStyle(appLabel)
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
