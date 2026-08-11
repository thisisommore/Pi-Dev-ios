//
//  Pi_Dev_MacApp.swift
//  Pi Dev Mac
//

import SwiftUI

@main
struct Pi_Dev_MacApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: 1180, height: 760)
        .windowResizability(.contentMinSize)
        // Unified compact keeps traffic lights in-line with content under full-size chrome.
        .windowToolbarStyle(.unifiedCompact(showsTitle: false))
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Chat") {
                    NotificationCenter.default.post(name: .newChatRequested, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command])
            }
        }

        Settings {
            Form {
                Section("Appearance") {
                    Text("Pi Dev Mac uses system light/dark appearance.")
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .frame(width: 420, height: 160)
        }
    }
}

extension Notification.Name {
    static let newChatRequested = Notification.Name("PiDevMac.newChatRequested")
}
