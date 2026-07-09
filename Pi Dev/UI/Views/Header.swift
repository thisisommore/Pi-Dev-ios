//
//  Header.swift
//  Pi Dev
//

import SwiftUI

struct Header: View {
  @Bindable var store: ChatStore
  @Binding var showModelSheet: Bool
  @Binding var showSidebar: Bool
  var onNewChat: () -> Void = {}
  @State private var showRenameAlert = false
  @State private var renameDraft = ""

  private func dismissKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
  }

  var body: some View {
    GlassEffectContainer(spacing: 12) {
      HStack(spacing: 12) {
        Button {
          withAnimation(.snappy) {
            showSidebar.toggle()
          }
          dismissKeyboard()
        } label: {
          Image(systemName: "line.3.horizontal")
            .font(.system(size: 17, weight: .semibold))
            .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive())

        Menu {
          Button {
            renameDraft = store.chatTitle
            showRenameAlert = true
          } label: {
            Label("Edit", systemImage: "pencil")
          }
          if !store.messages.isEmpty {
            Button {
              store.forkChat()
            } label: {
              Label("Fork", systemImage: "arrow.branch")
            }
          }
        } label: {
          HStack {
            Text(store.chatTitle)
              .font(.subheadline.weight(.semibold))
              .foregroundColor(.primary)
              .lineLimit(1)
            Spacer(minLength: 0)
          }
          .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .tint(.primary)
        .animation(.linear(duration: 0), value: store.chatTitle)
        .frame(maxWidth: .infinity, alignment: .leading)

        ContextGauge(
          fraction: store.contextFraction,
          used: store.usedTokens,
          window: store.selectedModel?.contextWindow ?? 200_000
        )
        .frame(width: 44, height: 44)
        .glassEffect(.regular)

        Button {
          onNewChat()
        } label: {
          Image(systemName: "square.and.pencil")
            .font(.system(size: 17, weight: .semibold))
            .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive())
      }
      .padding(.horizontal, 16)
      .padding(.top, 6)
      .padding(.bottom, 10)
    }
    .blur(radius: store.editingMessageId != nil ? 10 : 0)
    .allowsHitTesting(store.editingMessageId == nil)
    .animation(.snappy, value: store.editingMessageId != nil)
    .alert("Rename chat", isPresented: $showRenameAlert) {
      TextField("Chat name", text: $renameDraft)
      Button("Cancel", role: .cancel) {}
      Button("Save") {
        let trimmed = renameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
          store.chatTitle = trimmed
        }
      }
    }
  }
}
