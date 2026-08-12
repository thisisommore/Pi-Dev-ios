//
//  AppDatabase.swift
//  Pi Dev
//
//  SQLiteData bootstrap — prepares the default database for the app,
//  previews, and tests. Cache tables land in follow-up migrations.
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
        if context == .preview {
          print($0.expandedDescription)
        } else {
          logger.debug("\($0.expandedDescription)")
        }
      }
    }
  #endif

  let database = try defaultDatabase(configuration: configuration)
  logger.info("open '\(database.path)'")

  var migrator = DatabaseMigrator()
  #if DEBUG
    // Rebuild automatically while schema is still in flux.
    migrator.eraseDatabaseOnSchemaChange = true
  #endif

  migrator.registerMigration("v1_bootstrap") { db in
    // Key/value scratch space until real cache tables are added.
    try #sql(
      """
      CREATE TABLE "appMeta"(
        "key" TEXT NOT NULL PRIMARY KEY,
        "value" TEXT NOT NULL
      ) STRICT
      """
    )
    .execute(db)
  }

  try migrator.migrate(database)
  return database
}

private let logger = Logger(subsystem: "PiDev", category: "Database")
