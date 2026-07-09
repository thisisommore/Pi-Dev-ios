//
//  IncludedRepo.swift
//  Pi Dev
//

import Foundation

struct IncludedRepo: Identifiable, Hashable, Sendable {
  let id = UUID()
  let url: String
  let name: String
}
