//
//  QueuedMessage.swift
//  Pi Dev
//

import Foundation

struct QueuedMessage: Identifiable, Equatable {
  let id: UUID
  let text: String
  let queueIndex: Int

  init(id: UUID = UUID(), text: String, queueIndex: Int) {
    self.id = id
    self.text = text
    self.queueIndex = queueIndex
  }
}
