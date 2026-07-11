//
//  ComposerView.swift
//  Pi Dev Mac
//

import SwiftUI

struct ComposerView: View {
    @Bindable var store: ChatStore
    @FocusState private var focused: Bool

    private var canSend: Bool {
        !store.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            composerCard
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 18)
        .padding(.top, 8)
        .frame(maxWidth: 820)
        .frame(maxWidth: .infinity)
        .onChange(of: store.isComposerFocused) { _, wantFocus in
            if wantFocus {
                focused = true
                store.isComposerFocused = false
            }
        }
    }

    private var composerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Do anything…", text: $store.draft, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.body)
                .lineLimit(1...8)
                .focused($focused)
                .onSubmit {
                    // Return sends on macOS when not holding option; shift-return can still expand via axis.
                    if canSend { store.sendDraft() }
                }

            HStack(spacing: 8) {
                modelPicker
                thinkingLevelPicker
                Spacer(minLength: 0)
                attachButton
                sendButton
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.background)
                .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
                .shadow(color: .black.opacity(0.03), radius: 1, y: 0)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }

    private var attachButton: some View {
        Menu {
            Button("Attach file…") {}
            Button("Add folder…") {}
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Add context")
    }

    private var modelPicker: some View {
        Menu {
            ForEach(AIModelOption.catalog) { model in
                Button {
                    store.selectedModel = model
                } label: {
                    Label {
                        VStack(alignment: .leading) {
                            Text(model.name)
                            Text(model.subtitle)
                                .font(.caption)
                        }
                    } icon: {
                        Image(systemName: model.symbol)
                    }
                }
            }
        } label: {
            Text(store.selectedModel.name)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Model")
    }

    private var thinkingLevelPicker: some View {
        Menu {
            ForEach(ThinkingLevel.all) { level in
                Button {
                    store.selectedThinkingLevel = level
                } label: {
                    Label {
                        VStack(alignment: .leading) {
                            Text(level.displayName)
                            Text(level.subtitle)
                                .font(.caption)
                        }
                    } icon: {
                        Image(systemName: level.symbol)
                    }
                }
            }
        } label: {
            Text(store.selectedThinkingLevel.displayName)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Thinking level")
    }

    private var sendButton: some View {
        Button {
            store.sendDraft()
        } label: {
            Image(systemName: "arrow.up")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(canSend ? .white : .secondary)
                .frame(width: 28, height: 28)
                .background {
                    Circle()
                        .fill(canSend ? Color.accentColor : Color.primary.opacity(0.08))
                }
        }
        .buttonStyle(.plain)
        .disabled(!canSend)
        .keyboardShortcut(.return, modifiers: .command)
        .help("Send")
        .animation(.snappy(duration: 0.15), value: canSend)
    }
}

#Preview {
    ComposerView(store: ChatStore())
        .padding()
        .frame(width: 720)
}
