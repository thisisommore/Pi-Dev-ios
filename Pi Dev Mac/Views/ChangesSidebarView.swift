//
//  ChangesSidebarView.swift
//  Pi Dev Mac
//

import SwiftUI

struct ChangesSidebarView: View {
    @Bindable var store: ChatStore

    private var changes: [FileChange] {
        store.selectedSession?.fileChanges ?? []
    }

    private var totalAdditions: Int {
        changes.reduce(0) { $0 + $1.additions }
    }

    private var totalDeletions: Int {
        changes.reduce(0) { $0 + $1.deletions }
    }

    private var selectionFill: Color {
        Color(nsColor: .unemphasizedSelectedContentBackgroundColor)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            changesList
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .safeAreaPadding(.top, 0)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("Changes")
                .font(.headline.weight(.semibold))
            Spacer(minLength: 0)
            HStack(spacing: 4) {
                Text("+\(totalAdditions)")
                    .foregroundStyle(.green)
                Text("-\(totalDeletions)")
                    .foregroundStyle(.red)
            }
            .font(.caption.weight(.semibold))
            .monospacedDigit()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var changesList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                ForEach(changes) { change in
                    changeRow(change)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
        }
        .scrollContentBackground(.hidden)
        .background(Color.clear)
    }

    private func changeRow(_ change: FileChange) -> some View {
        let isSelected = store.selectedChangeFileID == change.id

        return Button {
            store.selectedChangeFileID = change.id
        } label: {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(change.fileName)
                        .font(.callout.weight(.medium))
                        .lineLimit(1)
                        .foregroundStyle(.primary)

                    Text(change.path)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                HStack(spacing: 4) {
                    Text("+\(change.additions)")
                        .foregroundStyle(.green)
                    Text("-\(change.deletions)")
                        .foregroundStyle(.red)
                }
                .font(.caption.weight(.medium))
                .monospacedDigit()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected ? selectionFill : Color.clear)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ChangesSidebarView(store: ChatStore())
        .frame(width: 260, height: 640)
        .background(Color(nsColor: .controlBackgroundColor))
}
