//
//  ThinkingBlock.swift
//  Pi Dev
//

import SwiftUI
import Combine
import UIKit

struct ThinkingBlock: View {
  let thinking: Thinking
  var isStreaming = false
  @State private var showSheet = false
  @State private var textHeight: CGFloat = 0

  private var lineHeight: CGFloat {
    UIFont.preferredFont(forTextStyle: .caption1).lineHeight
  }

  private var viewportHeight: CGFloat { lineHeight * 2 }

  /// While live and taller than 2 lines, pin to the newest text. When it stops, first 2 lines.
  private var slideOffset: CGFloat {
    guard isStreaming, textHeight > viewportHeight else { return 0 }
    return viewportHeight - textHeight
  }

  var body: some View {
    Button {
      withAnimation(.snappy) { showSheet = true }
    } label: {
      Text(thinking.summary)
        .font(.caption)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.leading)
        .fixedSize(horizontal: false, vertical: true)
        .background {
          GeometryReader { geo in
            Color.clear
              .onAppear { textHeight = geo.size.height }
              .onChange(of: geo.size.height) { _, height in
                textHeight = height
              }
          }
        }
        .offset(y: slideOffset)
        .animation(.linear(duration: 0.2), value: slideOffset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: viewportHeight, alignment: .top)
        .clipped()
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

      Text("Thinking")
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
