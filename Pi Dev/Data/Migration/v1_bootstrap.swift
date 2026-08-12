//
//  v1_bootstrap.swift
//  Pi Dev
//

import SQLiteData

extension DatabaseMigrator {
  mutating func v1() {
    self.registerMigration("v1_bootstrap") { db in
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
  }
}
