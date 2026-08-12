//
//  v2_cache.swift
//  Pi Dev
//

import SQLiteData

extension DatabaseMigrator {
  mutating func v2() {
    self.registerMigration("v2_cache") { db in
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
  }
}
