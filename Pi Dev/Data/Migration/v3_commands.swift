//
//  v3_commands.swift
//  Pi Dev
//

import SQLiteData

extension DatabaseMigrator {
  mutating func v3() {
    self.registerMigration("v3_commands") { db in
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
  }
}
