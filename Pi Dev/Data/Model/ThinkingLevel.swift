//
//  ThinkingLevel.swift
//  Pi Dev
//

import Foundation

enum ThinkingLevel: String, CaseIterable, Identifiable {
  case off = "Off"
  case low = "Low"
  case medium = "Medium"
  case high = "High"

  var id: String { rawValue }

  var symbol: String {
    switch self {
    case .off:    "circle.slash"
    case .low:    "gauge.with.dots.needle.0percent"
    case .medium: "gauge.with.dots.needle.50percent"
    case .high:   "gauge.with.dots.needle.100percent"
    }
  }

  var budget: String {
    switch self {
    case .off:    "No extended thinking"
    case .low:    "~4k thinking tokens"
    case .medium: "~16k thinking tokens"
    case .high:   "~64k thinking tokens"
    }
  }
}
