//
//  ThinkingBlock.swift
//  Pi Dev
//

import SwiftUI

struct ThinkingBlock: View {
  let thinking: Thinking
  @State private var showSheet = false

  var body: some View {
    Button {
      withAnimation(.snappy) { showSheet = true }
    } label: {
      Text(thinking.summary)
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(2)
        .padding(.vertical, 8)
        .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .sheet(isPresented: $showSheet) {
      ThinkingSheet(thinking: thinking)
        .presentationDetents([.large])
        .presentationBackground(.thinMaterial)
        .presentationCornerRadius(32)
    }
  }
}

struct ThinkingSheet: View {
  let thinking: Thinking

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Capsule()
        .fill(.tertiary)
        .frame(width: 36, height: 5)
        .frame(maxWidth: .infinity)
        .padding(.top, 10)

      Text("Thinking · \(thinking.seconds, format: .number.precision(.fractionLength(1)))s")
        .font(.title3.weight(.bold))
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)

      ScrollView {
        Text(thinking.full)
          .font(.callout)
          .foregroundStyle(.secondary)
          .lineSpacing(3)
          .padding(.horizontal, 20)
          .padding(.bottom, 20)
      }
    }
  }
}
