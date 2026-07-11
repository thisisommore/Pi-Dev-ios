//
//  MessageViews.swift
//  Pi Dev Mac
//

import SwiftUI

// MARK: - Message list

struct MessageListView: View {
    let messages: [ChatMessage]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    ForEach(messages) { message in
                        MessageRowView(message: message)
                            .id(message.id)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 24)
                .frame(maxWidth: 820)
                .frame(maxWidth: .infinity)
            }
            .onChange(of: messages.count) { _, _ in
                guard let last = messages.last else { return }
                withAnimation(.easeOut(duration: 0.25)) {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
            .onAppear {
                guard let last = messages.last else { return }
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }
}

// MARK: - Single row

struct MessageRowView: View {
    let message: ChatMessage

    var body: some View {
        switch message.role {
        case .user:
            UserMessageView(message: message)
        case .assistant:
            AssistantMessageView(message: message)
        }
    }
}

// MARK: - User

struct UserMessageView: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Spacer(minLength: 80)
            Text(message.text)
                .font(.body)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.accentColor.opacity(0.12))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.accentColor.opacity(0.18), lineWidth: 1)
                }
        }
    }
}

// MARK: - Assistant

struct AssistantMessageView: View {
    let message: ChatMessage

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            MarkdownishText(text: message.text)
                .font(.body)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(message.codeBlocks) { block in
                CodeBlockView(block: block)
            }

            messageActions
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var messageActions: some View {
        HStack(spacing: 14) {
            ForEach(["doc.on.doc", "hand.thumbsup", "hand.thumbsdown", "arrow.triangle.2.circlepath"], id: \.self) { symbol in
                Button {} label: {
                    Image(systemName: symbol)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help(symbol)
            }
        }
        .padding(.top, 2)
    }
}

// MARK: - Lightweight markdown-ish rendering

/// Renders **bold**, simple bullets, and plain paragraphs without pulling in a full markdown stack.
struct MarkdownishText: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                switch block {
                case .paragraph(let runs):
                    Text(attributed(from: runs))
                        .lineSpacing(3)
                case .bullet(let runs):
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("•")
                            .foregroundStyle(.secondary)
                        Text(attributed(from: runs))
                            .lineSpacing(3)
                    }
                case .numbered(let number, let runs):
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(number).")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            .frame(minWidth: 18, alignment: .trailing)
                        Text(attributed(from: runs))
                            .lineSpacing(3)
                    }
                }
            }
        }
    }

    private enum Block {
        case paragraph([TextRun])
        case bullet([TextRun])
        case numbered(Int, [TextRun])
    }

    private enum TextRun {
        case plain(String)
        case bold(String)
    }

    private var blocks: [Block] {
        text
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .map { line in
                if line.hasPrefix("• ") || line.hasPrefix("- ") {
                    let content = String(line.dropFirst(2))
                    return .bullet(parseRuns(content))
                }
                if let match = line.range(of: #"^\d+\.\s+"#, options: .regularExpression) {
                    let number = Int(line[line.startIndex..<match.upperBound].filter(\.isNumber)) ?? 1
                    let content = String(line[match.upperBound...])
                    return .numbered(number, parseRuns(content))
                }
                return .paragraph(parseRuns(line))
            }
    }

    private func parseRuns(_ string: String) -> [TextRun] {
        var runs: [TextRun] = []
        var remaining = string[...]
        while let open = remaining.range(of: "**") {
            let before = String(remaining[..<open.lowerBound])
            if !before.isEmpty { runs.append(.plain(before)) }
            remaining = remaining[open.upperBound...]
            if let close = remaining.range(of: "**") {
                runs.append(.bold(String(remaining[..<close.lowerBound])))
                remaining = remaining[close.upperBound...]
            } else {
                runs.append(.plain("**" + remaining))
                remaining = ""
            }
        }
        if !remaining.isEmpty {
            runs.append(.plain(String(remaining)))
        }
        return runs
    }

    private func attributed(from runs: [TextRun]) -> AttributedString {
        var result = AttributedString()
        for run in runs {
            switch run {
            case .plain(let s):
                result += AttributedString(s)
            case .bold(let s):
                var bold = AttributedString(s)
                bold.font = .body.weight(.semibold)
                result += bold
            }
        }
        return result
    }
}

// MARK: - Code block

struct CodeBlockView: View {
    let block: CodeBlock
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(block.language)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Button {
                    copyToPasteboard(block.source)
                    withAnimation { copied = true }
                    Task {
                        try? await Task.sleep(for: .seconds(1.5))
                        withAnimation { copied = false }
                    }
                } label: {
                    Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                        .font(.caption)
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.primary.opacity(0.04))

            ScrollView(.horizontal, showsIndicators: false) {
                Text(block.source)
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .padding(12)
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.035))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func copyToPasteboard(_ string: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
        #endif
    }
}

#Preview {
    MessageListView(messages: MockData.sessions[0].messages)
        .frame(width: 720, height: 500)
}
