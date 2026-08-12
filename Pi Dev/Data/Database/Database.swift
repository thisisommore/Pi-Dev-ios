//
//  Database.swift
//  Pi Dev
//

import Dependencies
import OSLog
import SQLiteData

/// Creates and migrates the app's on-disk SQLite database.
///
/// Call once via `prepareDependencies { $0.defaultDatabase = try appDatabase() }`
/// as early as possible (app entry point).
func appDatabase() throws -> any DatabaseWriter {
  @Dependency(\.context) var context

  var configuration = Configuration()
  #if DEBUG
    configuration.prepareDatabase { db in
      db.trace(options: .profile) {
        if context != .preview {
          logger.debug("\($0.expandedDescription)")
        }
      }
    }
  #endif

  let database = try defaultDatabase(configuration: configuration)
  logger.info("open '\(database.path)'")

  var migrator = DatabaseMigrator()
  #if DEBUG
    migrator.eraseDatabaseOnSchemaChange = true
  #endif

  migrator.v1()
  migrator.v2()
  migrator.v3()
  try migrator.migrate(database)
  return database
}

private let logger = Logger(subsystem: "PiDev", category: "Database")
