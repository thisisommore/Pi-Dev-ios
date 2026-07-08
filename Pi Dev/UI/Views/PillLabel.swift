//
//  PillLabel.swift
//  Pi Dev
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
      Image(systemName: "chevron.up.chevron.down")
        .font(.system(size: 7, weight: .bold))
        .foregroundStyle(.tertiary)
    }
    .padding(.horizontal, 11)
    .padding(.vertical, 8)
    .contentShape(.capsule)
  }
}
