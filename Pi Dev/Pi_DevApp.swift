//
//  Pi_DevApp.swift
//  Pi Dev
//
//  Created by Om More on 07/07/26.
//

import SwiftUI

@main
struct Pi_DevApp: App {
    @AppStorage("piServerBaseURL") private var serverURL = ""
    @AppStorage("piAuthToken") private var authToken = ""

    var body: some Scene {
        WindowGroup {
            Group {
                if serverURL.isEmpty || authToken.isEmpty {
                    SetupView()
                } else {
                    AICodeChatView()
                }
            }
        }
    }
}
