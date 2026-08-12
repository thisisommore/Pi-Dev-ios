//
//  Main.swift
//  Pi Dev
//

import SQLiteData
import SwiftUI

@main
struct Main: App {
  init() {
    prepareDependencies {
      $0.defaultDatabase = try! appDatabase()
    }
  }

  var body: some Scene {
    WindowGroup {
      Provider {
        Root()
      }
    }
  }
}
