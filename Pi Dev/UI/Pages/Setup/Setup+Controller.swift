//
//  Setup+Controller.swift
//  Pi Dev
//

import Observation
import SwiftUI
import Combine

@MainActor
@Observable
final class SetupPageController {
  var urlDraft = ""
  var tokenDraft = ""
  var isChecking = false
  var errorMessage: String?
  var showHelp = false

  enum Field: Hashable {
    case url, token
  }

  @ObservationIgnored
  @AppStorage("piServerBaseURL") private var serverURL = ""
  @ObservationIgnored
  @AppStorage("piAuthToken") private var authToken = ""

  var normalizedURL: String {
    let trimmed = self.urlDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return "" }
    if trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://") {
      return trimmed
    }
    return "https://\(trimmed)"
  }

  var canContinue: Bool {
    guard !self.isChecking else { return false }
    guard !self.tokenDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
    guard let url = URL(string: self.normalizedURL),
          url.host != nil,
          url.scheme?.hasPrefix("http") == true
    else { return false }
    return true
  }

  func hydrateFromStorage() {
    self.urlDraft = self.serverURL
    self.tokenDraft = self.authToken
  }

  func continueTapped() {
    let trimmedToken = self.tokenDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedToken.isEmpty, let url = URL(string: self.normalizedURL) else { return }

    self.isChecking = true
    self.errorMessage = nil

    Task { @MainActor in
      let client = PiRPCClient(baseURL: url, authToken: trimmedToken)
      let result = await client.healthCheck()

      self.isChecking = false

      switch result {
      case .success:
        withAnimation(.snappy) {
          self.serverURL = url.absoluteString
          self.authToken = trimmedToken
        }
      case .failure(let error):
        self.errorMessage = error.localizedDescription
      }
    }
  }
}
