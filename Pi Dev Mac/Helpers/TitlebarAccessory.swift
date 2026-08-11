//
//  TitlebarAccessory.swift
//  Pi Dev Mac
//
//  Adds a trailing title-bar button for toggling the right changes sidebar.
//

import AppKit
import SwiftUI

struct ChangesSidebarTitlebarButton: NSViewRepresentable {
    @Bindable var store: ChatStore

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.isHidden = true
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            guard !context.coordinator.isInstalled else { return }

            let buttonView = TitlebarChangesButton(store: store)
            let hostingView = NSHostingView(rootView: buttonView)
            hostingView.frame.size = hostingView.fittingSize

            let accessory = NSTitlebarAccessoryViewController()
            accessory.view = hostingView
            accessory.layoutAttribute = .trailing

            window.addTitlebarAccessoryViewController(accessory)
            context.coordinator.isInstalled = true
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var isInstalled = false
    }
}

private struct TitlebarChangesButton: View {
    @Bindable var store: ChatStore

    var body: some View {
        Button {
            store.isChangesSidebarVisible.toggle()
        } label: {
            Image(systemName: "sidebar.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
        .help(store.isChangesSidebarVisible ? "Hide changes" : "Show changes")
        .frame(width: 28, height: 28)
        .contentShape(Rectangle())
        .padding(.trailing, 8)
    }
}
