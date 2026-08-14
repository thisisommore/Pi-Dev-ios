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

    private var folderLabel: String? {
        guard let path = store.selectedSession?.workingDir, !path.isEmpty else { return nil }
        return (path as NSString).lastPathComponent
    }

    var body: some View {
        VStack(spacing: 0) {
            composerCard
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
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
            if let folderLabel {
                HStack(spacing: 6) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 11, weight: .semibold))
                    Text(folderLabel)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.secondary.opacity(0.12), in: .capsule)
            }

            TextField("Ask about your code…", text: $store.draft, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.body)
                .lineLimit(1...8)
                .focused($focused)
                .onSubmit {
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
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }

    private var attachButton: some View {
        Menu {
            Button("Attachment") {}
            Button {
                store.showFolderPicker = true
            } label: {
                Label("Folder", systemImage: "folder")
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(appLabel)
                .frame(width: 32, height: 32)
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
            PillLabel(symbol: nil, text: store.selectedModel.name)
                .foregroundStyle(.secondary)
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
            PillLabel(symbol: nil, text: store.selectedThinkingLevel.displayName)
                .foregroundStyle(.secondary)
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
                .foregroundStyle(canSend ? appOnInk : .secondary)
                .frame(width: 32, height: 32)
                .background {
                    Circle()
                        .fill(canSend ? appColor : Color.primary.opacity(0.10))
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
