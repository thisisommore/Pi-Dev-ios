//
//  Composer.swift
//  Pi Dev
//

import SwiftUI
import UniformTypeIdentifiers

struct Composer: View {
  @Bindable var store: ChatStore
  @Binding var showModelSheet: Bool
  @FocusState private var focused: Bool
  @State private var selectedPastedItem: PastedItem?
  @State private var selectedContextFile: ContextFile?
  @State private var showFileImporter = false
  @State private var showClearAlert = false
  @State private var showRepoSheet = false
  @Environment(\.colorScheme) private var colorScheme

  private var hasAttachments: Bool { !store.pastedItems.isEmpty || !store.contextFiles.isEmpty }
  var body: some View {
    GlassEffectContainer(spacing: 10) {
      mainContent
    }
    .fileImporter(
      isPresented: $showFileImporter,
      allowedContentTypes: [.plainText, .sourceCode, .data],
      allowsMultipleSelection: true
    ) { result in
      importFiles(from: result)
    }
    .sheet(item: $selectedPastedItem) { item in
      AttachmentSheet(title: "Pasted content", content: item.content, monospaced: false)
        .presentationDetents([.medium])
        .presentationBackground(.thinMaterial)
        .presentationCornerRadius(32)
    }
    .sheet(item: $selectedContextFile) { file in
      AttachmentSheet(title: file.name, content: file.content, monospaced: true)
        .presentationDetents([.medium])
        .presentationBackground(.thinMaterial)
        .presentationCornerRadius(32)
    }
    .sheet(isPresented: $showRepoSheet) {
      RepoPickerSheet(store: store)
        .presentationDetents([.large])
        .presentationBackground(.thinMaterial)
        .presentationCornerRadius(32)
    }
    .alert("Clear all attachments?", isPresented: $showClearAlert) {
      Button("Cancel", role: .cancel) {}
      Button("Clear", role: .destructive) {
        withAnimation(.snappy) {
          store.pastedItems = []
          store.contextFiles = []
        }
      }
    } message: {
      Text("This will remove all attachments")
    }
  }

  private var mainContent: some View {
    VStack(spacing: 10) {
      VStack(spacing: 0) {
        if !store.messageQueue.isEmpty {
          VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(store.queuedMessagesForDisplay.enumerated()), id: \.element.id) { index, queued in
              QueuedMessageRow(queued: queued, isFirst: index == 0) {
                store.removeQueuedMessage(at: queued.id)
              }
            }
          }
          .padding(.horizontal, 34)
        }

        inputCard
      }
    }
  }

  private var inputCard: some View {
    VStack(spacing: 0) {
      if hasAttachments {
        HStack {
          Spacer()
          Button("Clear all") {
            showClearAlert = true
          }
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)

        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 8) {
            ForEach(store.pastedItems) { item in
              attachmentCard(
                icon: "doc.on.clipboard",
                title: "Pasted",
                preview: item.content,
                onTap: { selectedPastedItem = item },
                onRemove: {
                  withAnimation(.snappy) {
                    store.pastedItems.removeAll { $0.id == item.id }
                  }
                }
              )
            }
            ForEach(store.contextFiles) { file in
              attachmentCard(
                icon: "doc.text",
                title: file.name,
                preview: file.content,
                onTap: { selectedContextFile = file },
                onRemove: {
                  withAnimation(.snappy) {
                    store.contextFiles.removeAll { $0.id == file.id }
                  }
                }
              )
            }
          }
          .padding(.horizontal, 14)
          .padding(.top, 6)
        }
        .scrollClipDisabled()
      }

      TextField(
        store.editingMessageId != nil ? "Edit message…" : "Ask about your code…",
        text: $store.draft,
        prompt: Text(store.editingMessageId != nil ? "Edit message…" : "Ask about your code…").foregroundColor(.gray.opacity(0.7)),
        axis: .vertical
      )
      .lineLimit(1...5)
      .focused($focused)
      .font(.callout)
      .onSubmit {
        focused = false
        store.send()
      }
      .onChange(of: store.editingMessageId) { _, id in
        if id != nil { focused = true }
      }
      .onChange(of: store.draft) { oldValue, newValue in
        guard store.editingMessageId == nil else { return }
        let delta = newValue.count - oldValue.count
        if delta > 3 && newValue.count > 50 {
          store.pastedItems.append(PastedItem(content: newValue))
          store.draft = ""
        }
      }
      .padding(.top, hasAttachments ? 8 : 14)
      .padding(.horizontal, 14)

      toolbar
    }
    .background(
      colorScheme == .dark
        ? AnyShapeStyle(.ultraThickMaterial)
        : AnyShapeStyle(.white),
      in: .rect(cornerRadius: 26)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 26)
        .stroke(.secondary.opacity(colorScheme == .dark ? 0.25 : 0.15), lineWidth: 0.5)
    )
    .compositingGroup()
    .padding(.horizontal, 16)
    .padding(.bottom, 8)
  }

  private var toolbar: some View {
    HStack(spacing: 8) {
      Button {
        showModelSheet = true
      } label: {
        PillLabel(symbol: nil, text: store.selectedModel?.name ?? "Model")
      }
      .buttonStyle(.plain)
      .glassEffect(.regular.interactive(), in: .capsule)

      Menu {
        Picker("Thinking", selection: $store.thinkingLevel) {
          ForEach(store.supportedThinkingLevels) { level in
            Label {
              Text(level.displayName)
              Text(level.budget)
            } icon: {
              Image(systemName: level.symbol)
            }
            .tag(level)
          }
        }
      } label: {
        PillLabel(symbol: nil, text: store.thinkingLevel.displayName)
      }
      .buttonStyle(.plain)
      .glassEffect(.regular.interactive(), in: .capsule)

      Spacer()

      Menu {
        Button {
          showFileImporter = true
        } label: {
          Label("Attachment", systemImage: "paperclip")
        }

        Button {
          showRepoSheet = true
        } label: {
          Label("Repository", systemImage: "arrow.triangle.branch")
        }
      } label: {
        Image(systemName: "plus")
          .font(.system(size: 16, weight: .semibold))
          .foregroundStyle(.primary)
          .frame(width: 40, height: 40)
      }
      .buttonStyle(.plain)
      .menuStyle(.borderlessButton)
      .tint(.primary)

      Button {
        focused = false
        store.send()
      } label: {
        Image(systemName: "arrow.up")
          .font(.system(size: 15, weight: .bold))
          .frame(width: 40, height: 40)
          .foregroundStyle(.white)
          .background(AnyShapeStyle(appColor.gradient),
            in: .circle
          )
      }
      .buttonStyle(.plain)
      .disabled(store.draft.isEmpty && store.pastedItems.isEmpty && store.contextFiles.isEmpty)
      .animation(.snappy, value: store.draft.isEmpty && store.pastedItems.isEmpty && store.contextFiles.isEmpty)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 6)
    .padding(.horizontal, 10)
  }

  private func attachmentCard(
    icon: String,
    title: String,
    preview: String,
    onTap: @escaping () -> Void,
    onRemove: @escaping () -> Void
  ) -> some View {
    HStack(alignment: .top, spacing: 8) {
      Button(action: onTap) {
        VStack(alignment: .leading, spacing: 4) {
          HStack(spacing: 6) {
            Image(systemName: icon)
              .font(.system(size: 11, weight: .semibold))
            Text(title)
              .font(.caption.weight(.semibold))
              .lineLimit(1)
          }
          Text(String(preview.prefix(200)))
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
            .lineLimit(3)
            .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(.primary)
      }
      .buttonStyle(.plain)

      Button(action: onRemove) {
        Image(systemName: "xmark")
          .font(.system(size: 10, weight: .bold))
          .foregroundStyle(.secondary)
          .frame(width: 22, height: 22)
          .background(.secondary.opacity(0.15), in: .circle)
      }
      .buttonStyle(.plain)
    }
    .frame(width: 150, alignment: .leading)
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(.secondary.opacity(0.12), in: .rect(cornerRadius: 12))
  }

  private func importFiles(from result: Result<[URL], Error>) {
    switch result {
    case .success(let urls):
      Task { @MainActor in
        for url in urls {
          let gotAccess = url.startAccessingSecurityScopedResource()
          defer { if gotAccess { url.stopAccessingSecurityScopedResource() } }
          if let content = try? String(contentsOf: url, encoding: .utf8) {
            let name = url.lastPathComponent
            store.contextFiles.append(ContextFile(name: name, content: content))
          }
        }
      }
    case .failure:
      break
    }
  }

}
