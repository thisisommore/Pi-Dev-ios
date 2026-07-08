//
//  AICodeChat+ModelSheet.swift
//  Pi Dev
//

import SwiftUI

struct ModelSheet: View {
  @Bindable var store: ChatStore

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Capsule()
        .fill(.tertiary)
        .frame(width: 36, height: 5)
        .frame(maxWidth: .infinity)
        .padding(.top, 10)

      ModelList(store: store, models: AIModel.allCases)

      Spacer(minLength: 0)
    }
  }
}

struct ModelList: View {
  @Bindable var store: ChatStore
  let models: [AIModel]

  var body: some View {
    ScrollView(showsIndicators: false) {
      VStack(spacing: 0) {
        ForEach(models) { model in
          ModelRow(store: store, model: model)

          if model != models.last {
            Divider()
              .padding(.leading, 20)
          }
        }
      }
      .background(.secondary.opacity(0.12), in: .rect(cornerRadius: 16))
      .clipShape(.rect(cornerRadius: 16))
      .padding(.horizontal, 16)
      .padding(.top, 4)
    }
  }
}

struct ModelRow: View {
  @Bindable var store: ChatStore
  @Environment(\.dismiss) private var dismiss
  let model: AIModel

  var body: some View {
    Button {
      withAnimation(.snappy) { store.model = model }
      dismiss()
    } label: {
      HStack {
        Text(model.rawValue)
          .font(.subheadline.weight(.semibold))
        Spacer()
        if store.model == model {
          Image(systemName: "checkmark")
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(.primary)
        }
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 14)
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .background(store.model == model ? Color.secondary.opacity(0.15) : .clear)
  }
}
