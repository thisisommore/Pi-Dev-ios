//
//  FileDiffView.swift
//  Pi Dev Mac
//

import SwiftUI

struct FileDiffView: View {
    let change: FileChange

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            diffContent
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(change.path)
                .font(.callout.weight(.medium))
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)

            HStack(spacing: 4) {
                Text("+\(change.additions)")
                    .foregroundStyle(.green)
                Text("-\(change.deletions)")
                    .foregroundStyle(.red)
            }
            .font(.caption.weight(.semibold))
            .monospacedDigit()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .textBackgroundColor))
    }

    private var diffContent: some View {
        ScrollView {
            Text(change.diff)
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    FileDiffView(
        change: FileChange(
            path: "Sources/Network/RetryPolicy.swift",
            additions: 56,
            deletions: 0,
            diff: """
            +import Foundation
            +
            +struct RetryPolicy {
            +    let maxAttempts: Int
            +    let baseDelay: Duration
            +    let maxDelay: Duration
            +}
            """
        )
    )
    .frame(width: 600, height: 500)
}
