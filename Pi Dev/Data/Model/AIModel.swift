//
//  AIModel.swift
//  Pi Dev
//

import Foundation

/// Legacy local model catalogue — not used at runtime.
/// The app now uses `AgentModel` decoded from the server (`get_available_models`
/// / `get_state`). Kept for previews / docs only.
@available(*, deprecated, message: "Use AgentModel from server instead")
enum AIModel: String, CaseIterable, Identifiable {
  case fable = "Fable 5"
  case opus = "Opus 4.8"
  case sonnet = "Sonnet 4.6"
  case haiku = "Haiku 4.5"

  var id: String { rawValue }

  var symbol: String {
    switch self {
    case .fable:  "sparkles"
    case .opus:   "brain.head.profile"
    case .sonnet: "bolt.fill"
    case .haiku:  "wind"
    }
  }

  var blurb: String {
    switch self {
    case .fable:  "Deepest reasoning · slow"
    case .opus:   "Frontier coding · balanced"
    case .sonnet: "Everyday coding · fast"
    case .haiku:  "Instant answers · fastest"
    }
  }

  var contextWindow: Int {
    switch self {
    case .fable:  1_000_000
    case .opus:   500_000
    case .sonnet: 200_000
    case .haiku:  200_000
    }
  }
}
