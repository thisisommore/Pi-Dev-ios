//
//  AICodeChat+Sidebar.swift
//  Pi Dev
//

import SwiftUI

struct Sidebar: View {
  @Bindable var store: SidebarStore

  var body: some View {
    ZStack {
      Color(.systemBackground)
        .ignoresSafeArea()
      LinearGradient(
        colors: [appColor.opacity(0.08), .clear, .teal.opacity(0.06)],
        startPoint: .topLeading, endPoint: .bottomTrailing
      )
      .ignoresSafeArea()

      VStack(spacing: 0) {
        HStack {
          Button {
            Task { @MainActor in
              await store.newChat()
            }
          } label: {
            Image(systemName: "square.and.pencil")
              .font(.system(size: 16, weight: .light))
              .frame(width: 36, height: 36)
          }
          .buttonStyle(.plain)
          .glassEffect(.regular.interactive(), in: .circle)
          Spacer()
          Text("πcode")
            .font(.largeTitle)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)

        ScrollView {
          LazyVStack(spacing: 8) {
            if store.filteredSessions.isEmpty {
              Text("No sessions")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 80)
            } else {
              ForEach(store.filteredSessions) { session in
                Button {
                  Task { @MainActor in
                    await store.select(session: session)
                  }
                } label: {
                  HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                      Text(store.sessionTitle(session))
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                      if session.messageCount > 0 {
                        Text("\(session.messageCount) messages")
                          .font(.caption2)
                          .foregroundStyle(.secondary)
                      }
                    }
                    if store.selectedSessionId == session.id {
                      Circle()
                        .fill(.primary)
                        .frame(width: 6, height: 6)
                    }
                  }
                  .padding(.horizontal, 14)
                  .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
                .background {
                  if store.selectedSessionId == session.id {
                    Color.clear
                      .glassEffect(.regular, in: .rect(cornerRadius: 12))
                  }
                }
                .contextMenu {
                  Button(role: .destructive) {
                    Task { @MainActor in
                      await store.delete(session: session)
                    }
                  } label: {
                    Label("Delete", systemImage: "trash")
                  }
                }
              }
            }
          }
          .padding(.horizontal, 16)
          .padding(.top, 4)
        }

        Spacer(minLength: 0)
      }
    }
  }
}
