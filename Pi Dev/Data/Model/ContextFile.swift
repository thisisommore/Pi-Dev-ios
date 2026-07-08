//
//  ContextFile.swift
//  Pi Dev
//

import Foundation

struct ContextFile: Identifiable {
  let id = UUID()
  let name: String
  let content: String
}
