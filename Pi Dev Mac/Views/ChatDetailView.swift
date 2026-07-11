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
            if let session = store.selectedSession {
                if session.messages.isEmpty {
                    EmptyStateView(store: store, sessionTitle: session.title)
                } else {
                    MessageListView(messages: session.messages)
                }
                ComposerView(store: store)
            } else {
                noSelection
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .navigationTitle(store.selectedSession?.title ?? "Pi Dev")
        .navigationSubtitle(subtitle)
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
        }
    }

    private var subtitle: String {
        if let project = store.selectedSession?.projectName {
            return project
        }
        if let count = store.selectedSession?.messages.count, count > 0 {
            return "\(count) messages"
        }
        return " "
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
