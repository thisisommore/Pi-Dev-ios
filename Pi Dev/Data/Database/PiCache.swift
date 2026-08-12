//
//  PiCache.swift
//  Pi Dev
//
//  Cache-first persistence for sessions, models, and chat transcripts.
//

import Dependencies
import Foundation
import OSLog
import SQLiteData

/// Snapshot applied on launch / session switch before network revalidation.
struct CacheBootstrap: Sendable {
  var sessions: [SessionInfo]
  var lastSessionId: String?
  var models: [AgentModel]
  var lastModelId: String?
  var chat: CachedChatSnapshot?
}

struct CachedChatSnapshot: Sendable {
  var sessionId: String
  var title: String
  var usedTokens: Int
  var selectedModelId: String?
  var thinkingLevel: String
  var messages: [ChatMessage]
}

enum PiCache {
  private static let prefsId = "main"
  private static let logger = Logger(subsystem: "PiDev", category: "Cache")

  /// Fingerprint for the configured server so caches don't leak across hosts.
  static var serverKey: String {
    UserDefaults.standard.string(forKey: "piServerBaseURL")?
      .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
  }

  // MARK: - Load

  static func loadBootstrap() -> CacheBootstrap? {
    let key = serverKey
    guard !key.isEmpty else { return nil }

    do {
      @Dependency(\.defaultDatabase) var database
      return try database.read { db in
        let prefs = try CachePrefsRow
          .where { $0.id.eq(prefsId) }
          .fetchOne(db)

        // Prefer rows for this server; ignore foreign-server leftovers.
        let sessionRows = try CachedSessionRow
          .where { $0.serverKey.eq(key) }
          .order(by: \.position)
          .fetchAll(db)

        let modelRows = try CachedModelRow
          .where { $0.serverKey.eq(key) }
          .order(by: \.position)
          .fetchAll(db)

        guard !sessionRows.isEmpty || !modelRows.isEmpty || prefs?.lastSessionId != nil else {
          return nil
        }

        let lastSessionId: String? = {
          if let id = prefs?.lastSessionId, prefs?.serverKey == key { return id }
          return sessionRows.first?.id
        }()

        var chat: CachedChatSnapshot?
        if let lastSessionId {
          chat = try loadChat(sessionId: lastSessionId, serverKey: key, db: db)
        }

        return CacheBootstrap(
          sessions: sessionRows.map(\.asSessionInfo),
          lastSessionId: lastSessionId,
          models: modelRows.map(\.asAgentModel),
          lastModelId: prefs?.serverKey == key ? prefs?.lastModelId : nil,
          chat: chat
        )
      }
    } catch {
      logger.error("loadBootstrap failed: \(error.localizedDescription)")
      return nil
    }
  }

  static func loadChat(sessionId: String) -> CachedChatSnapshot? {
    let key = serverKey
    guard !key.isEmpty else { return nil }
    do {
      @Dependency(\.defaultDatabase) var database
      return try database.read { db in
        try loadChat(sessionId: sessionId, serverKey: key, db: db)
      }
    } catch {
      logger.error("loadChat failed: \(error.localizedDescription)")
      return nil
    }
  }

  private static func loadChat(
    sessionId: String,
    serverKey: String,
    db: Database
  ) throws -> CachedChatSnapshot? {
    let row = try CachedChatRow
      .where { $0.sessionId.eq(sessionId) && $0.serverKey.eq(serverKey) }
      .fetchOne(db)
    guard let row, let data = row.messagesJSON.data(using: .utf8) else { return nil }

    let dtos = try JSONDecoder().decode([CachedMessageDTO].self, from: data)
    return CachedChatSnapshot(
      sessionId: row.sessionId,
      title: row.title,
      usedTokens: row.usedTokens,
      selectedModelId: row.selectedModelId,
      thinkingLevel: row.thinkingLevel,
      messages: dtos.map { $0.asChatMessage() }
    )
  }

  // MARK: - Save

  static func saveSessions(_ sessions: [SessionInfo]) {
    let key = serverKey
    guard !key.isEmpty else { return }
    do {
      @Dependency(\.defaultDatabase) var database
      try database.write { db in
        try CachedSessionRow.where { $0.serverKey.eq(key) }.delete().execute(db)
        for (index, session) in sessions.enumerated() {
          try CachedSessionRow.insert {
            CachedSessionRow(session: session, position: index, serverKey: key)
          }
          .execute(db)
        }
      }
    } catch {
      logger.error("saveSessions failed: \(error.localizedDescription)")
    }
  }

  static func saveModels(_ models: [AgentModel]) {
    let key = serverKey
    guard !key.isEmpty else { return }
    do {
      @Dependency(\.defaultDatabase) var database
      try database.write { db in
        try CachedModelRow.where { $0.serverKey.eq(key) }.delete().execute(db)
        for (index, model) in models.enumerated() {
          try CachedModelRow.insert {
            CachedModelRow(model: model, position: index, serverKey: key)
          }
          .execute(db)
        }
      }
    } catch {
      logger.error("saveModels failed: \(error.localizedDescription)")
    }
  }

  static func saveChat(
    sessionId: String,
    title: String,
    usedTokens: Int,
    selectedModelId: String?,
    thinkingLevel: ThinkingLevel,
    messages: [ChatMessage]
  ) {
    let key = serverKey
    guard !key.isEmpty, !sessionId.isEmpty else { return }

    // Don't persist mid-stream snapshots.
    let stable = messages.filter { !$0.isStreaming }
    guard !stable.isEmpty || messages.isEmpty else { return }

    do {
      let dtos = stable.map(CachedMessageDTO.init)
      let data = try JSONEncoder().encode(dtos)
      let json = String(data: data, encoding: .utf8) ?? "[]"

      @Dependency(\.defaultDatabase) var database
      try database.write { db in
        try CachedChatRow
          .where { $0.sessionId.eq(sessionId) }
          .delete()
          .execute(db)
        try CachedChatRow.insert {
          CachedChatRow(
            sessionId: sessionId,
            title: title,
            usedTokens: usedTokens,
            selectedModelId: selectedModelId,
            thinkingLevel: thinkingLevel.id,
            messagesJSON: json,
            serverKey: key,
            updatedAt: Date().timeIntervalSince1970
          )
        }
        .execute(db)
      }
    } catch {
      logger.error("saveChat failed: \(error.localizedDescription)")
    }
  }

  static func savePrefs(lastSessionId: String?, lastModelId: String?) {
    writePrefs { row in
      row.lastSessionId = lastSessionId
      row.lastModelId = lastModelId
    }
  }

  static func saveLastSessionId(_ id: String?) {
    writePrefs { $0.lastSessionId = id }
  }

  static func saveLastModelId(_ id: String?) {
    writePrefs { $0.lastModelId = id }
  }

  private static func writePrefs(_ update: (inout CachePrefsRow) -> Void) {
    let key = serverKey
    guard !key.isEmpty else { return }
    do {
      @Dependency(\.defaultDatabase) var database
      try database.write { db in
        var row =
          try CachePrefsRow.where { $0.id.eq(prefsId) }.fetchOne(db)
          ?? CachePrefsRow(
            id: prefsId,
            lastSessionId: nil,
            lastModelId: nil,
            serverKey: key,
            updatedAt: 0
          )
        // If the server changed, drop foreign ids.
        if row.serverKey != key {
          row = CachePrefsRow(
            id: prefsId,
            lastSessionId: nil,
            lastModelId: nil,
            serverKey: key,
            updatedAt: 0
          )
        }
        update(&row)
        row.serverKey = key
        row.updatedAt = Date().timeIntervalSince1970
        try CachePrefsRow.where { $0.id.eq(prefsId) }.delete().execute(db)
        try CachePrefsRow.insert { row }.execute(db)
      }
    } catch {
      logger.error("savePrefs failed: \(error.localizedDescription)")
    }
  }

  static func clearAll() {
    do {
      @Dependency(\.defaultDatabase) var database
      try database.write { db in
        try CachedSessionRow.delete().execute(db)
        try CachedModelRow.delete().execute(db)
        try CachedChatRow.delete().execute(db)
        try CachePrefsRow.delete().execute(db)
      }
    } catch {
      logger.error("clearAll failed: \(error.localizedDescription)")
    }
  }
}
