//
//  AICodeChat+ModelSheet.swift
//  Pi Dev
//

import SwiftUI

struct ModelSheet: View {
  @Bindable var store: ChatStore
  @State private var searchText = ""

  private var filteredModels: [AgentModel] {
    let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard !query.isEmpty else { return store.availableModels }
    return store.availableModels.filter {
      $0.name.lowercased().contains(query)
        || ($0.provider?.lowercased().contains(query) ?? false)
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Capsule()
        .fill(.tertiary)
        .frame(width: 36, height: 5)
        .frame(maxWidth: .infinity)
        .padding(.top, 10)

      HStack(spacing: 10) {
        Image(systemName: "magnifyingglass")
          .font(.system(size: 14, weight: .medium))
          .foregroundStyle(.secondary)

        TextField("Search models", text: $searchText)
          .font(.callout)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()

        if !searchText.isEmpty {
          Button {
            searchText = ""
          } label: {
            Image(systemName: "xmark.circle.fill")
              .font(.system(size: 18))
              .foregroundStyle(.secondary)
          }
          .buttonStyle(.plain)
        }
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 10)
      .background(.secondary.opacity(0.12), in: .rect(cornerRadius: 12))
      .padding(.horizontal, 16)
      .padding(.top, 4)

      ModelList(store: store, models: filteredModels)

      Spacer(minLength: 0)
    }
  }
}

struct ModelList: View {
  @Bindable var store: ChatStore
  let models: [AgentModel]

  var body: some View {
    ScrollView(showsIndicators: false) {
      VStack(spacing: 0) {
        if models.isEmpty {
          Text("No models available")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 80)
        } else {
          ForEach(models, id: \.id) { model in
            ModelRow(store: store, model: model)

            if model.id != models.last?.id {
              Divider()
                .padding(.leading, 20)
            }
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
  let model: AgentModel

  var body: some View {
    Button {
      Task { @MainActor in
        await store.selectModel(model)
        dismiss()
      }
    } label: {
      HStack {
        VStack(alignment: .leading, spacing: 2) {
          Text(model.name)
            .font(.subheadline.weight(.semibold))
          if let contextWindow = model.contextWindow {
            Text("\(contextWindow.formatted(.number.notation(.compactName))) context")
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
        }
        Spacer()
        if store.selectedModel?.id == model.id {
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
    .background(store.selectedModel?.id == model.id ? Color.secondary.opacity(0.15) : .clear)
  }
}
