//
//  EmptyStateView.swift
//  Pi Dev Mac
//

import SwiftUI

struct EmptyStateView: View {
    var body: some View {
        Text("π")
            .font(.system(size: 40, weight: .thin, design: .serif))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    EmptyStateView()
        .frame(width: 800, height: 500)
}
