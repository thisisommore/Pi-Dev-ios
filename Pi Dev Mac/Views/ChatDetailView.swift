//
//  ChatDetailView.swift
//  Pi Dev Mac
//

import SwiftUI

struct ChatDetailView: View {
    @Bindable var store: ChatStore
    @Binding var isSidebarVisible: Bool

    var body: some View {
        VStack(spacing: 0) {
            if let change = store.selectedFileChange, store.isChangesSidebarVisible {
                FileDiffView(change: change)
            } else if let session = store.selectedSession {
                if session.messages.isEmpty {
                    EmptyStateView()
                } else {
                    MessageListView(store: store, messages: session.messages)
                }
                ComposerView(store: store)
            } else {
                noSelection
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .navigationTitle("")
        .toolbarRole(.editor)
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    isSidebarVisible.toggle()
                } label: {
                    Label(
                        isSidebarVisible ? "Hide Sidebar" : "Show Sidebar",
                        systemImage: "sidebar.left"
                    )
                }
                .help(isSidebarVisible ? "Hide sidebar" : "Show sidebar")
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    store.showFolderPicker = true
                } label: {
                    Label("Open folder", systemImage: "folder")
                }
                .help("Open folder")
            }
        }
    }

    private var noSelection: some View {
        ContentUnavailableView {
            Label("No chat selected", systemImage: "bubble.left.and.bubble.right")
        } description: {
            Text("Pick a conversation from the sidebar or start a new one.")
        } actions: {
            Button("New chat") {
                store.newChat()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    NavigationStack {
        ChatDetailView(store: ChatStore(), isSidebarVisible: .constant(true))
    }
    .frame(width: 800, height: 640)
}
