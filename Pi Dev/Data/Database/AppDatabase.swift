//
//  AppDatabase.swift
//  Pi Dev
//
//  SQLiteData bootstrap — prepares the default database for the app,
//  previews, and tests.
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

  migrator.registerMigration("v2_cache") { db in
    try #sql(
      """
      CREATE TABLE "cachedSessions"(
        "id" TEXT NOT NULL PRIMARY KEY,
        "path" TEXT NOT NULL,
        "cwd" TEXT NOT NULL,
        "name" TEXT,
        "created" TEXT NOT NULL,
        "modified" TEXT NOT NULL,
        "messageCount" INTEGER NOT NULL DEFAULT 0,
        "firstMessage" TEXT,
        "allMessagesText" TEXT,
        "position" INTEGER NOT NULL DEFAULT 0,
        "serverKey" TEXT NOT NULL
      ) STRICT
      """
    )
    .execute(db)

    try #sql(
      """
      CREATE TABLE "cachedModels"(
        "id" TEXT NOT NULL PRIMARY KEY,
        "name" TEXT NOT NULL,
        "provider" TEXT,
        "contextWindow" INTEGER,
        "thinkingLevelMapJSON" TEXT,
        "position" INTEGER NOT NULL DEFAULT 0,
        "serverKey" TEXT NOT NULL
      ) STRICT
      """
    )
    .execute(db)

    try #sql(
      """
      CREATE TABLE "cachedChats"(
        "sessionId" TEXT NOT NULL PRIMARY KEY,
        "title" TEXT NOT NULL,
        "usedTokens" INTEGER NOT NULL DEFAULT 0,
        "selectedModelId" TEXT,
        "thinkingLevel" TEXT NOT NULL DEFAULT 'high',
        "messagesJSON" TEXT NOT NULL,
        "serverKey" TEXT NOT NULL,
        "updatedAt" REAL NOT NULL DEFAULT 0
      ) STRICT
      """
    )
    .execute(db)

    try #sql(
      """
      CREATE TABLE "cachePrefs"(
        "id" TEXT NOT NULL PRIMARY KEY,
        "lastSessionId" TEXT,
        "lastModelId" TEXT,
        "serverKey" TEXT NOT NULL,
        "updatedAt" REAL NOT NULL DEFAULT 0
      ) STRICT
      """
    )
    .execute(db)

    try #sql(
      """
      CREATE INDEX "idx_cachedSessions_serverKey"
      ON "cachedSessions"("serverKey")
      """
    )
    .execute(db)

    try #sql(
      """
      CREATE INDEX "idx_cachedModels_serverKey"
      ON "cachedModels"("serverKey")
      """
    )
    .execute(db)
  }

  migrator.registerMigration("v3_commands") { db in
    try #sql(
      """
      CREATE TABLE "cachedCommands"(
        "name" TEXT NOT NULL PRIMARY KEY,
        "desc" TEXT,
        "source" TEXT NOT NULL,
        "location" TEXT,
        "path" TEXT,
        "position" INTEGER NOT NULL DEFAULT 0,
        "serverKey" TEXT NOT NULL
      ) STRICT
      """
    )
    .execute(db)

    try #sql(
      """
      CREATE INDEX "idx_cachedCommands_serverKey"
      ON "cachedCommands"("serverKey")
      """
    )
    .execute(db)
  }

  try migrator.migrate(database)
  return database
}

private let logger = Logger(subsystem: "PiDev", category: "Database")
