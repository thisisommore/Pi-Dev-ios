//
//  QueuedMessageRow.swift
//  Pi Dev
//

import SwiftUI

struct QueuedMessageRow: View {
  let queued: QueuedMessage
  let isFirst: Bool
  let onRemove: () -> Void
  @Environment(\.colorScheme) private var colorScheme

  private var rowShape: some Shape {
    isFirst
      ? .rect(cornerRadii: .init(topLeading: 12, bottomLeading: 0, bottomTrailing: 0, topTrailing: 12))
      : .rect(cornerRadii: .init(topLeading: 0, bottomLeading: 0, bottomTrailing: 0, topTrailing: 0))
  }

  var body: some View {
    HStack(spacing: 8) {
      Text(queued.text)
        .font(.caption)
        .lineLimit(2)
      Spacer()
      Image(systemName: "arrow.up")
        .font(.system(size: 10, weight: .bold))
        .foregroundStyle(.secondary)
      Button(action: onRemove) {
        Image(systemName: "xmark")
          .font(.system(size: 10, weight: .bold))
          .foregroundStyle(.secondary)
      }
      .buttonStyle(.plain)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(
      colorScheme == .dark
        ? AnyShapeStyle(.ultraThickMaterial)
        : AnyShapeStyle(.white),
      in: rowShape
    )
    .overlay(
      rowShape
        .stroke(.secondary.opacity(0.25), lineWidth: 0.5)
    )
  }
}
