//
//  ToolsViews.swift
//  Pi Dev Mac
//

import SwiftUI

struct ToolsDisclosure: View {
    let items: [ToolActivity]
    @Binding var isExpanded: Bool

    private var title: String {
        items.count == 1 ? "1 tool" : "\(items.count) tools"
    }

    var body: some View {
        if items.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Button {
                    isExpanded.toggle()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "wrench.and.screwdriver")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)

                        Text(title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.tertiary)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.secondary.opacity(0.08), in: .rect(cornerRadius: 12))
                    .contentShape(.rect(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                if isExpanded {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(items) { item in
                            switch item {
                            case .tool(let tool):
                                ToolChip(tool: tool)
                            case .terminal(let run):
                                TerminalBlock(run: run)
                            }
                        }
                    }
                    .padding(.leading, 4)
                }
            }
        }
    }
}

struct ToolChip: View {
    let tool: ToolUse

    private var isDiff: Bool { isDiffStat(tool.detail) }
    private var isCommand: Bool {
        let n = tool.name.lowercased()
        return n == "bash" || n.contains("bash") || n.contains("run") || n.contains("shell")
            || tool.detail.hasPrefix("command:")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(tool.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if isDiff {
                    DiffLabel(text: tool.detail)
                }

                Spacer(minLength: 0)
            }

            if !tool.detail.isEmpty && !isDiff {
                Text(displayDetail)
                    .font(isCommand ? .system(size: 12, design: .monospaced) : .caption)
                    .foregroundStyle(.primary.opacity(0.75))
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.secondary.opacity(0.08), in: .rect(cornerRadius: 12))
    }

    private var displayDetail: String {
        let detail = tool.detail.trimmingCharacters(in: .whitespacesAndNewlines)
        if detail.isEmpty { return detail }
        if let stripped = stripSingleKeyPrefix(detail, key: "command") { return stripped }
        if let stripped = stripSingleKeyPrefix(detail, key: "path") { return stripped }
        if let stripped = stripSingleKeyPrefix(detail, key: "file") { return stripped }
        return detail
    }

    private func stripSingleKeyPrefix(_ text: String, key: String) -> String? {
        let prefix = "\(key):"
        guard text.lowercased().hasPrefix(prefix) else { return nil }
        let rest = text.dropFirst(prefix.count).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rest.isEmpty, !rest.contains("\n") else { return nil }
        return rest
    }
}

private func isDiffStat(_ text: String) -> Bool {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return false }
    let parts = trimmed.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
    let isToken: (String) -> Bool = { part in
        guard let first = part.first, first == "+" || first == "-" || first == "−" else { return false }
        let digits = part.dropFirst()
        return !digits.isEmpty && digits.allSatisfy(\.isNumber)
    }
    return !parts.isEmpty && parts.allSatisfy(isToken)
}

struct DiffLabel: View {
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
                Text(part)
                    .foregroundStyle(color(for: part))
            }
        }
        .font(.caption.monospacedDigit().weight(.medium))
    }

    private var parts: [String] {
        text.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
    }

    private func color(for part: String) -> Color {
        if part.hasPrefix("+") { return .primary }
        if part.hasPrefix("−") || part.hasPrefix("-") { return .secondary }
        return .secondary.opacity(0.6)
    }
}

struct TerminalBlock: View {
    let run: TerminalRun
    @State private var expanded = true

    private var succeeded: Bool { run.exitCode == 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                expanded.toggle()
            } label: {
                HStack(alignment: .top, spacing: 8) {
                    Text(run.command)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(appLabel)
                        .lineLimit(expanded ? 4 : 1)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)

                    if !succeeded {
                        Text("exit \(run.exitCode)")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }

                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 2)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            if expanded {
                Divider().opacity(0.35)

                ScrollView(.horizontal, showsIndicators: false) {
                    Text(run.output.isEmpty ? "(no output)" : String(run.output.split(separator: "\n").prefix(4).joined(separator: "\n")))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(run.output.isEmpty ? .tertiary : .secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
        }
        .background(.secondary.opacity(0.10), in: .rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(.secondary.opacity(0.18), lineWidth: 1)
        )
    }
}

struct ThinkingBlock: View {
    let thinking: Thinking
    @State private var showSheet = false

    var body: some View {
        Button {
            showSheet = true
        } label: {
            Text(thinking.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showSheet) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Thinking")
                    .font(.title3.weight(.bold))
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 8)

                ScrollView {
                    Text(thinking.full)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                }
            }
            .frame(minWidth: 420, minHeight: 320)
        }
    }
}
