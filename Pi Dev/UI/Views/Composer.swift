//
//  Composer.swift
//  Pi Dev
//

import SwiftUI
import UniformTypeIdentifiers
import Combine

struct Composer: View {
  @Bindable var store: ChatStore
  @Binding var showModelSheet: Bool

  @Environment(\.colorScheme) private var colorScheme

  @FocusState private var focused: Bool
  @State private var selectedPastedItem: PastedItem?
  @State private var selectedContextFile: ContextFile?
  @State private var showFileImporter = false
  @State private var showClearAlert = false
  @State private var showRepoSheet = false
  @State private var showExpandSheet = false

  private var hasAttachments: Bool { !store.pastedItems.isEmpty || !store.contextFiles.isEmpty }
  private var canSendMessage: Bool {
    !(store.draft.isEmpty && store.pastedItems.isEmpty && store.contextFiles.isEmpty)
  }
  private var canExpandDraft: Bool { !store.draft.isEmpty }

  private var commandSuggestions: [PiCommand] {
    guard store.editingMessageId == nil else { return [] }
    return store.filteredCommands(for: store.draft)
  }

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
    .sheet(isPresented: $showExpandSheet) {
      ComposerExpandSheet(text: $store.draft)
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
                store.removeQueuedMessage(id: queued.id)
              }
            }
          }
          .padding(.horizontal, 14)
        }

        if !commandSuggestions.isEmpty {
          commandSuggestionsView
            .padding(.horizontal, 10)
            .padding(.bottom, 6)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }

        inputCard
      }
      .animation(.snappy(duration: 0.2), value: commandSuggestions)
    }
    .task {
      if store.availableCommands.isEmpty {
        await store.loadAvailableCommands()
      }
    }
  }

  private var commandSuggestionsView: some View {
    VStack(alignment: .leading, spacing: 0) {
      // Header
      HStack(spacing: 6) {
        Image(systemName: "command")
          .font(.system(size: 10, weight: .bold))
          .foregroundStyle(.secondary)
        Text("Commands")
          .font(.caption2.weight(.bold))
          .foregroundStyle(.secondary)
          .textCase(.uppercase)
        Spacer()
        Text("\(commandSuggestions.count)")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.tertiary)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 6)

      Divider().opacity(0.6)

      ScrollView(.vertical, showsIndicators: false) {
        VStack(spacing: 0) {
          ForEach(commandSuggestions) { cmd in
            Button {
              withAnimation(.snappy) {
                store.applyCommand(cmd)
              }
              // Keep focus in the composer after applying
              focused = true
            } label: {
              commandRow(for: cmd)
            }
            .buttonStyle(.plain)
            if cmd.id != commandSuggestions.last?.id {
              Divider().opacity(0.4).padding(.leading, 12)
            }
          }
        }
      }
      .frame(maxHeight: 220)
    }
    .background {
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .fill(.regularMaterial)
        .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
        .shadow(color: .black.opacity(0.04), radius: 1, y: 0)
    }
    .overlay {
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
    }
    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    .compositingGroup()
  }

  private func commandRow(for cmd: PiCommand) -> some View {
    HStack(spacing: 10) {
      VStack(alignment: .leading, spacing: 1) {
        Text(cmd.invocation)
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(appLabel)
          .lineLimit(1)
        if let desc = cmd.description, !desc.isEmpty {
          Text(desc)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        } else if let loc = cmd.location, !loc.isEmpty {
          Text(loc)
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .lineLimit(1)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .contentShape(.rect)
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

      HStack(alignment: .top, spacing: 8) {
        TextField(
          store.editingMessageId != nil ? "Edit message…" : "Ask about your code…",
          text: $store.draft,
          prompt: Text(store.editingMessageId != nil ? "Edit message…" : "Ask about your code…").foregroundColor(.gray.opacity(0.7)),
          axis: .vertical
        )
        .lineLimit(1...5)
        .focused($focused)
        .font(.callout)
        // Caret / selection tint (system default is blue).
        .tint(.primary)
        .onSubmit {
          focused = false
          store.send()
        }
        .onChange(of: store.editingMessageId) { _, id in
          if id != nil { focused = true }
        }
        .onChange(of: store.draft) { oldValue, newValue in
          guard store.editingMessageId == nil else { return }
          // Don't treat slash-command autocomplete as a paste.
          if newValue.trimmingCharacters(in: .whitespaces).hasPrefix("/") { return }
          let delta = newValue.count - oldValue.count
          if delta > 3 && newValue.count > 50 {
            store.pastedItems.append(PastedItem(content: newValue))
            store.draft = ""
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        if canExpandDraft {
          Button {
            focused = false
            showExpandSheet = true
          } label: {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
              .font(.system(size: 14, weight: .semibold))
              .foregroundStyle(.secondary)
              .frame(width: 36, height: 36)
              .background(Color.primary.opacity(0.06), in: .circle)
              .contentShape(.circle)
          }
          .buttonStyle(.plain)
          .accessibilityLabel("Expand editor")
          // Sit on the first text line (callout ~22pt) inside a 36pt control.
          .padding(.top, -2)
          .transition(.opacity.combined(with: .scale(scale: 0.9)))
        }
      }
      .animation(.snappy(duration: 0.15), value: canExpandDraft)
      .padding(.top, hasAttachments ? 8 : 12)
      .padding(.leading, 14)
      .padding(.trailing, canExpandDraft ? 10 : 14)

      toolbar
        // Keep controls above the home indicator.
        .padding(.bottom, 4)
    }
    // Full-bleed dock: flush to all edges, no corner radius.
    .background {
      Rectangle()
        .fill(
          colorScheme == .dark
            ? AnyShapeStyle(.ultraThickMaterial)
            : AnyShapeStyle(.white)
        )
        .ignoresSafeArea(edges: .bottom)
        .overlay(alignment: .top) {
          Rectangle()
            .fill(.secondary.opacity(colorScheme == .dark ? 0.25 : 0.15))
            .frame(height: 0.5)
        }
    }
    .compositingGroup()
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
      .layoutPriority(0)

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
      .fixedSize()

      Spacer(minLength: 4)

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
          .foregroundStyle(appLabel)
          .frame(width: 40, height: 40)
      }
      .buttonStyle(.plain)
      .menuStyle(.borderlessButton)
      .tint(.primary)
      .layoutPriority(1)

      if store.isGenerating {
        Button {
          store.stopGeneration()
        } label: {
          Image(systemName: "stop.fill")
            .font(.system(size: 13, weight: .bold))
            .frame(width: 40, height: 40)
            .foregroundStyle(.white)
            .background(Color.black, in: .circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Stop generation")
        .transition(.scale.combined(with: .opacity))
        .layoutPriority(1)
      } else {
        Button {
          focused = false
          store.send()
        } label: {
          Image(systemName: "arrow.up")
            .font(.system(size: 15, weight: .bold))
            .frame(width: 40, height: 40)
            .foregroundStyle(canSendMessage ? AnyShapeStyle(appOnInk) : AnyShapeStyle(.secondary))
            .background(
              canSendMessage ? AnyShapeStyle(appColor) : AnyShapeStyle(Color.primary.opacity(0.12)),
              in: .circle
            )
        }
        .buttonStyle(.plain)
        .disabled(!canSendMessage)
        .animation(.snappy, value: canSendMessage)
        .layoutPriority(1)
      }
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
        .foregroundStyle(appLabel)
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

