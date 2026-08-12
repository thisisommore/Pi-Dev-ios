//
//  Root.swift
//  Pi Dev
//

import SwiftUI
import Combine

struct Root: View {
  @AppStorage("piServerBaseURL") private var serverURL = ""
  @AppStorage("piAuthToken") private var authToken = ""

  private var isConfigured: Bool {
    !self.serverURL.isEmpty && !self.authToken.isEmpty
  }

  var body: some View {
    Group {
      if self.isConfigured {
        Destination.chat.destinationView()
      } else {
        Destination.setup.destinationView()
      }
    }
  }
}
