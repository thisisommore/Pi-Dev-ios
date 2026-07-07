//
//  Pi_DevApp.swift
//  Pi Dev
//
//  Created by Om More on 07/07/26.
//

import SwiftUI

@main
struct Pi_DevApp: App {
    var body: some Scene {
        WindowGroup {
            AICodeChatView()
                .preferredColorScheme(.dark)
        }
    }
}
