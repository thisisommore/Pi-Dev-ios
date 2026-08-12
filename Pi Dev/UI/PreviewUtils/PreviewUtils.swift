//
//  PreviewUtils.swift
//  Pi Dev
//

import Dependencies
import SQLiteData
import SwiftUI

/// Preview wrapper: prepares the database, then shows canned chat (DEBUG / previews).
struct Mock<Content: View>: View {
  @ViewBuilder let content: () -> Content

  init(@ViewBuilder content: @escaping () -> Content) {
    self.content = content
    let _ = prepareDependencies {
      $0.defaultDatabase = try! appDatabase()
    }
  }

  var body: some View {
    self.content()
  }
}

enum PreviewUtils {
  @MainActor
  static func sidebarStore() -> SidebarStore {
    .preview
  }
}
