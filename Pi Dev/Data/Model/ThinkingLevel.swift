//
//  ThinkingLevel.swift
//  Pi Dev
//

import Foundation

struct ThinkingLevel: Hashable, Identifiable, Sendable {
  let id: String

  init(id: String) {
    self.id = id.lowercased()
  }

  static let off = ThinkingLevel(id: "off")
  static let minimal = ThinkingLevel(id: "minimal")
  static let low = ThinkingLevel(id: "low")
  static let medium = ThinkingLevel(id: "medium")
  static let high = ThinkingLevel(id: "high")

  /// The canonical levels the server is expected to support by default.
  static let defaultLevels: [ThinkingLevel] = [off, minimal, low, medium, high]

  var displayName: String { id.capitalized }

  var symbol: String {
    switch id {
    case "off":     "circle.slash"
    case "minimal": "gauge.with.dots.needle.0percent"
    case "low":     "gauge.with.dots.needle.0percent"
    case "medium":  "gauge.with.dots.needle.50percent"
    case "high":    "gauge.with.dots.needle.100percent"
    default:        "gauge.with.dots.needle.100percent"
    }
  }

  var budget: String {
    switch id {
    case "off":     "No extended thinking"
    case "minimal": "~1k thinking tokens"
    case "low":     "~4k thinking tokens"
    case "medium":  "~16k thinking tokens"
    case "high":    "~64k thinking tokens"
    default:        "Extended thinking"
    }
  }
}
