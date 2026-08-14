//
//  AICodeChat+Sidebar.swift
//  Pi Dev
//

import SwiftUI
import Combine

struct Sidebar: View {
  @Bindable var store: SidebarStore
  @Binding var showRemoteFolder: Bool
  @AppStorage("piServerBaseURL") private var serverURL = ""
  @AppStorage("piAuthToken") private var authToken = ""

  var body: some View {
    ZStack {
      Color(.systemBackground)
        .ignoresSafeArea()
      LinearGradient(
        colors: [Color.primary.opacity(0.04), .clear, Color.primary.opacity(0.03)],
        startPoint: .topLeading, endPoint: .bottomTrailing
      )
      .ignoresSafeArea()

      VStack(spacing: 0) {
        HStack {
          Text("πcode")
            .font(.largeTitle)
          Spacer()
          Button {
            showRemoteFolder = true
          } label: {
            Image(systemName: "folder")
              .font(.system(size: 16, weight: .light))
              .frame(width: 36, height: 36)
              .contentShape(Circle())
          }
          .buttonStyle(.plain)
          .glassEffect(.regular.interactive(), in: .circle)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)

        ScrollView {
          LazyVStack(spacing: 0) {
            // Optimistic draft for new chat: show immediately after first message
            // before server has returned the new sessionId. Replaced by real
            // entry once adoptNewChatSession loads sessions.
            if store.selectedSessionId == nil, !store.activeChat.messages.isEmpty {
              Button {} label: {
                HStack(spacing: 10) {
                  VStack(alignment: .leading, spacing: 2) {
                    Text(store.activeChat.chatTitle)
                      .font(.subheadline.weight(.regular))
                      .lineLimit(1)
                      .frame(maxWidth: .infinity, alignment: .leading)
                  }
                  Circle()
                    .fill(.primary)
                    .frame(width: 6, height: 6)
                }
                .frame(maxWidth: .infinity)
                .contentShape(.rect)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
              }
              .buttonStyle(.plain)
              .background {
                Color.clear
                  .glassEffect(.regular, in: .rect(cornerRadius: 12))
              }
              Divider()
                .opacity(0.5)
                .padding(.horizontal, 14)
                .padding(.top, 4)
            }
            if store.filteredSessions.isEmpty {
              // Keep placeholder only when there is no draft either.
              if store.selectedSessionId != nil || store.activeChat.messages.isEmpty {
                Text("No sessions")
                  .font(.subheadline)
                  .foregroundStyle(.secondary)
                  .frame(maxWidth: .infinity, minHeight: 80)
              }
            } else {
              ForEach(store.groupedSessions, id: \.day) { group in
                Text(store.sectionTitle(for: group.day))
                  .font(.title3.weight(.bold))
                  .frame(maxWidth: .infinity, alignment: .leading)
                  .padding(.horizontal, 0)
                  .padding(.vertical, 18)

                ForEach(Array(group.sessions.enumerated()), id: \.element.id) { index, session in
                  Button {
                    Task { @MainActor in
                      await store.select(session: session)
                    }
                  } label: {
                    HStack(spacing: 10) {
                      VStack(alignment: .leading, spacing: 2) {
                        Text(store.sessionTitle(session))
                          .font(.subheadline.weight(.regular))
                          .lineLimit(1)
                          .frame(maxWidth: .infinity, alignment: .leading)
                      }
                      if store.selectedSessionId == session.id {
                        Circle()
                          .fill(.primary)
                          .frame(width: 6, height: 6)
                      }
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(.rect)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
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

                  if index < group.sessions.count - 1 {
                    Divider()
                      .opacity(0.5)
                      .padding(.horizontal, 14)
                  }
                }
              }
            }
          }
          .padding(.horizontal, 16)
          .padding(.top, 4)
        }

        Spacer(minLength: 0)

        Divider()
          .padding(.horizontal, 16)

        Button {
          store.logout()
          serverURL = ""
          authToken = ""
        } label: {
          HStack(spacing: 10) {
            Image(systemName: "rectangle.portrait.and.arrow.forward")
              .font(.system(size: 15, weight: .regular))
              .frame(width: 24)
            Text("Log Out")
              .font(.subheadline.weight(.medium))
            Spacer()
          }
          .foregroundStyle(.secondary)
          .padding(.horizontal, 16)
          .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
        .padding(.bottom, 8)
      }
    }
  }
}
