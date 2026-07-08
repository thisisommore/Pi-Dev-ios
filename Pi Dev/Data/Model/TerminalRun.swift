//
//  TerminalRun.swift
//  Pi Dev
//

import Foundation

struct TerminalRun: Identifiable {
  let id = UUID()
  let command: String
  let output: String
  let exitCode: Int
}
