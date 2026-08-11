//
//  EmptyStateView.swift
//  Pi Dev Mac
//

import SwiftUI

struct EmptyStateView: View {
    @Bindable var store: ChatStore
    var sessionTitle: String?

    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 40)

            ZStack {
                Circle()
                    .fill(Color.primary.opacity(0.04))
                    .frame(width: 72, height: 72)
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(.tertiary)
            }

            VStack(spacing: 8) {
                Text(headline)
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)

                Text("Describe a task, paste code, or pick a starting point below.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            suggestionGrid

            Spacer(minLength: 20)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: 720)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var headline: String {
        if let sessionTitle, !sessionTitle.isEmpty, sessionTitle != "New chat" {
            return "What should we work on in \(sessionTitle)?"
        }
        if let project = store.selectedSession?.projectName {
            return "What should we work on in \(project)?"
        }
        return "What should we work on?"
    }

    private var suggestionGrid: some View {
        HStack(spacing: 12) {
            ForEach(PromptSuggestion.emptyState) { suggestion in
                Button {
                    store.applySuggestion(suggestion)
                } label: {
                    VStack(alignment: .leading, spacing: 14) {
                        Image(systemName: suggestion.symbol)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(suggestion.tint)
                        Text(suggestion.title)
                            .font(.callout.weight(.medium))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, minHeight: 100, alignment: .topLeading)
                    .padding(16)
                    .background {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.primary.opacity(0.03))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: 640)
    }
}

#Preview {
    EmptyStateView(store: ChatStore())
        .frame(width: 800, height: 500)
}
