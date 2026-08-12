//
//  Navigation.swift
//  Pi Dev
//

import Foundation
import SwiftUI
import Combine

final class AppNavigationPath: Observable, ObservableObject {
  @Published var path = NavigationPath()
}

enum Destination: Hashable {
  case setup
  case chat
}

extension Destination {
  @MainActor @ViewBuilder
  func _destinationView() -> some View {
    switch self {
    case .setup:
      SetupPage()
    case .chat:
      AICodeChatView()
    }
  }

  @MainActor
  func destinationView() -> some View {
    self._destinationView()
  }
}
