//
//  PillLabel.swift
//  Pi Dev Mac
//

import SwiftUI

struct PillLabel: View {
    let symbol: String?
    let text: String

    var body: some View {
        HStack(spacing: 5) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 10, weight: .semibold))
            }
            Text(text)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .contentShape(.capsule)
    }
}
