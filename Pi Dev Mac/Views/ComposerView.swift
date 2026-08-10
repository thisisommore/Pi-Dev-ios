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
                Spacer(minLength: 0)
                sendButton
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 6)
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
