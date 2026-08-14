//
//  RemoteFolderSheet.swift
//  Pi Dev
//

import SwiftUI

private enum RemoteFolderLayout {
  case grid, list
}

struct RemoteFolderSheet: View {
  let rpcClient: any PiRPCP

  @Environment(\.dismiss) private var dismiss
  @State private var dirStack: [String] = ["~"]
  @State private var currentPath = ""
  @State private var homePath: String?
  @State private var items: [RemoteFileEntry] = []
  @State private var selectedIds: Set<String> = []
  @State private var layout: RemoteFolderLayout = .grid
  @State private var isLoading = false
  @State private var errorMessage: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Capsule()
        .fill(.tertiary)
        .frame(width: 36, height: 5)
        .frame(maxWidth: .infinity)
        .padding(.top, 10)

      HStack(spacing: 12) {
        if dirStack.count > 1 {
          Button {
            dirStack.removeLast()
            Task { await load() }
          } label: {
            Image(systemName: "chevron.left")
              .font(.system(size: 16, weight: .semibold))
              .foregroundStyle(appLabel)
              .frame(width: 32, height: 32)
          }
          .buttonStyle(.plain)
        }

        VStack(alignment: .leading, spacing: 2) {
          Text(titleName)
            .font(.title3.weight(.bold))
            .lineLimit(1)
          Text(breadcrumb)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }

        Spacer(minLength: 0)

        Button("Done") {
          dismiss()
        }
        .font(.body.weight(.semibold))
        .foregroundStyle(appLabel)
      }
      .padding(.horizontal, 20)
      .padding(.top, 12)
      .padding(.bottom, 8)

      HStack {
        if !selectedIds.isEmpty {
          Text("\(selectedIds.count) selected")
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
        }
        Spacer(minLength: 0)
        Picker("Layout", selection: $layout) {
          Image(systemName: "square.grid.2x2").tag(RemoteFolderLayout.grid)
          Image(systemName: "list.bullet").tag(RemoteFolderLayout.list)
        }
        .pickerStyle(.segmented)
        .frame(width: 88)
      }
      .padding(.horizontal, 20)
      .padding(.bottom, 8)

      Group {
        if isLoading && items.isEmpty {
          ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage, items.isEmpty {
          VStack(spacing: 12) {
            Text(errorMessage)
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .multilineTextAlignment(.center)
            Button("Retry") {
              Task { await load() }
            }
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .padding(.horizontal, 24)
        } else {
          ScrollView {
            if layout == .grid {
              gridContent
            } else {
              listContent
            }
          }
          .overlay {
            if isLoading {
              ProgressView()
            }
          }
        }
      }
    }
    .task {
      await load()
    }
  }

  private var titleName: String {
    if dirStack.count == 1 { return "Home" }
    return (currentPath as NSString).lastPathComponent
  }

  private var breadcrumb: String {
    guard !currentPath.isEmpty else { return "Home" }
    if let homePath, currentPath.hasPrefix(homePath) {
      let rest = String(currentPath.dropFirst(homePath.count))
      return rest.isEmpty ? "~" : "~\(rest)"
    }
    return currentPath
  }

  private var gridContent: some View {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 16)], spacing: 16) {
      ForEach(items) { entry in
        Button {
          tap(entry)
        } label: {
          VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
              Image(systemName: entry.isFolder ? "folder.fill" : "doc")
                .font(.system(size: 44, weight: .regular))
                .foregroundStyle(entry.isFolder ? appIcon : appLabel)
                .frame(width: 72, height: 56)

              if !entry.isFolder, selectedIds.contains(entry.path) {
                Image(systemName: "checkmark.circle.fill")
                  .font(.system(size: 16, weight: .semibold))
                  .foregroundStyle(appColor)
                  .offset(x: 6, y: -4)
              }
            }
            Text(entry.name)
              .font(.caption)
              .foregroundStyle(appLabel)
              .lineLimit(2)
              .multilineTextAlignment(.center)
              .frame(maxWidth: .infinity)
          }
          .padding(.vertical, 8)
          .contentShape(.rect)
        }
        .buttonStyle(.plain)
      }
    }
    .padding(.horizontal, 20)
    .padding(.bottom, 20)
  }

  private var listContent: some View {
    LazyVStack(spacing: 0) {
      ForEach(Array(items.enumerated()), id: \.element.id) { index, entry in
        Button {
          tap(entry)
        } label: {
          HStack(spacing: 12) {
            Image(systemName: entry.isFolder ? "folder.fill" : "doc")
              .font(.system(size: 18, weight: .regular))
              .foregroundStyle(entry.isFolder ? appIcon : appLabel)
              .frame(width: 28)

            Text(entry.name)
              .font(.subheadline)
              .foregroundStyle(appLabel)
              .lineLimit(1)
              .frame(maxWidth: .infinity, alignment: .leading)

            if entry.isFolder {
              Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary)
            } else if selectedIds.contains(entry.path) {
              Image(systemName: "checkmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(appColor)
            }
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 12)
          .contentShape(.rect)
        }
        .buttonStyle(.plain)

        if index < items.count - 1 {
          Divider()
            .opacity(0.5)
            .padding(.leading, 56)
        }
      }
    }
    .padding(.horizontal, 8)
    .padding(.bottom, 20)
  }

  private func tap(_ entry: RemoteFileEntry) {
    if entry.isFolder {
      dirStack.append(entry.path)
      Task { await load() }
    } else {
      if selectedIds.contains(entry.path) {
        selectedIds.remove(entry.path)
      } else {
        selectedIds.insert(entry.path)
      }
    }
  }

  private func load() async {
    let dir = dirStack.last ?? "~"
    isLoading = true
    errorMessage = nil
    do {
      let result = try await rpcClient.listFiles(dir: dir)
      currentPath = result.path ?? dir
      if homePath == nil {
        homePath = result.path
      }
      items = result.entries ?? []
    } catch {
      errorMessage = error.localizedDescription
      items = []
    }
    isLoading = false
  }
}

#Preview {
  RemoteFolderSheet(rpcClient: PiRPCClient())
}
