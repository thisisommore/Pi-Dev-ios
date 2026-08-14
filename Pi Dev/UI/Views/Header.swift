//
//  Header.swift
//  Pi Dev
//

import SwiftUI
import Combine

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
    HStack(spacing: 12) {
        Button {
          withAnimation(.snappy) {
            showSidebar.toggle()
          }
          dismissKeyboard()
        } label: {
          Image(systemName: "equal")
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(appIcon)
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
          Text(store.chatTitle)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(appLabel)
            .lineLimit(1)
            .padding(.horizontal, 14)
            .frame(height: 44)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .tint(appIcon)
        .glassEffect(.regular.interactive(), in: .capsule)

        Spacer(minLength: 0)

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
            .foregroundStyle(appIcon)
            .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive())
      }
    .padding(.horizontal, 16)
    .padding(.top, 6)
    .padding(.bottom, 10)
    .foregroundStyle(appLabel)
    .blur(radius: store.editingMessageId != nil ? 10 : 0)
    .allowsHitTesting(store.editingMessageId == nil)
    .animation(.snappy, value: store.editingMessageId != nil)
    .alert("Rename chat", isPresented: $showRenameAlert) {
      TextField("Chat name", text: $renameDraft)
      Button("Cancel", role: .cancel) {}
      Button("Save") {
        Task { @MainActor in
          await store.renameSession(to: renameDraft)
        }
      }
    }
  }
}
