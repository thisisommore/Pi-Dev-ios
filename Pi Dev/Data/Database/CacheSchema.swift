//
//  CacheSchema.swift
//  Pi Dev
//
//  SQLiteData tables for offline / cache-first UI bootstrap.
//

import Foundation
import SQLiteData

// MARK: - Tables

/// Sidebar session rows (titles + metadata for grouping).
@Table("cachedSessions")
struct CachedSessionRow: Hashable, Identifiable, Sendable {
  @Column(primaryKey: true)
  let id: String
  var path: String
  var cwd: String
  var name: String?
  var created: String
  var modified: String
  var messageCount: Int
  var firstMessage: String?
  var allMessagesText: String?
  var position: Int
  var serverKey: String
}

/// Available models from the server.
@Table("cachedModels")
struct CachedModelRow: Hashable, Identifiable, Sendable {
  @Column(primaryKey: true)
  let id: String
  var name: String
  var provider: String?
  var contextWindow: Int?
  /// JSON object `[String: String?]` for thinking-level map, if any.
  var thinkingLevelMapJSON: String?
  var position: Int
  var serverKey: String
}

/// Full last-open (or recently opened) chat transcript as JSON.
@Table("cachedChats")
struct CachedChatRow: Hashable, Identifiable, Sendable {
  @Column(primaryKey: true)
  let sessionId: String
  var title: String
  var usedTokens: Int
  var selectedModelId: String?
  var thinkingLevel: String
  var messagesJSON: String
  var serverKey: String
  var updatedAt: Double

  var id: String { sessionId }
}

/// Cached pi commands (get_commands).
@Table("cachedCommands")
struct CachedCommandRow: Hashable, Identifiable, Sendable {
  @Column(primaryKey: true)
  let name: String
  @Column("desc")
  var desc: String?
  var source: String
  var location: String?
  var path: String?
  var position: Int
  var serverKey: String

  var id: String { name }
}

/// Singleton prefs row (`id` is always `"main"`).
@Table("cachePrefs")
struct CachePrefsRow: Hashable, Identifiable, Sendable {
  @Column(primaryKey: true)
  let id: String
  var lastSessionId: String?
  var lastModelId: String?
  var serverKey: String
  var updatedAt: Double
}

// MARK: - Message JSON payload

struct CachedMessageDTO: Codable, Sendable {
  var entryId: String?
  var role: String
  var text: String
  var codeLanguage: String?
  var codeSource: String?
  var thinkingSummary: String?
  var thinkingFull: String?
  var thinkingSeconds: Double?
  var tools: [CachedToolDTO]
  var terminal: [CachedTerminalDTO]
  var segments: [CachedSegmentDTO]
  var tokens: Int
  var error: String?
}

struct CachedToolDTO: Codable, Sendable {
  var kind: String
  var name: String
  var detail: String
  var symbol: String
  var callId: String?
}

struct CachedTerminalDTO: Codable, Sendable {
  var command: String
  var output: String
  var exitCode: Int
}

struct CachedSegmentDTO: Codable, Sendable {
  var kind: String  // text | tool | terminal
  var text: String?
  var tool: CachedToolDTO?
  var terminal: CachedTerminalDTO?
}

// MARK: - Domain mapping

extension CachedSessionRow {
  init(session: SessionInfo, position: Int, serverKey: String) {
    self.id = session.id
    self.path = session.path
    self.cwd = session.cwd
    self.name = session.name
    self.created = session.created
    self.modified = session.modified
    self.messageCount = session.messageCount
    self.firstMessage = session.firstMessage
    self.allMessagesText = session.allMessagesText
    self.position = position
    self.serverKey = serverKey
  }

  var asSessionInfo: SessionInfo {
    SessionInfo(
      path: path,
      id: id,
      cwd: cwd,
      name: name,
      created: created,
      modified: modified,
      messageCount: messageCount,
      firstMessage: firstMessage,
      allMessagesText: allMessagesText
    )
  }
}

extension CachedModelRow {
  init(model: AgentModel, position: Int, serverKey: String) {
    self.id = model.id
    self.name = model.name
    self.provider = model.provider
    self.contextWindow = model.contextWindow
    if let map = model.thinkingLevelMap {
      // JSONEncoder won't encode [String: String?]; use JSONSerialization.
      let object = map.mapValues { $0 as Any? ?? NSNull() }
      if let data = try? JSONSerialization.data(withJSONObject: object),
         let json = String(data: data, encoding: .utf8) {
        self.thinkingLevelMapJSON = json
      } else {
        self.thinkingLevelMapJSON = nil
      }
    } else {
      self.thinkingLevelMapJSON = nil
    }
    self.position = position
    self.serverKey = serverKey
  }

  var asAgentModel: AgentModel {
    var map: [String: String?]?
    if let thinkingLevelMapJSON,
       let data = thinkingLevelMapJSON.data(using: .utf8),
       let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
      map = object.mapValues { value -> String? in
        if value is NSNull { return nil }
        return value as? String
      }
    }
    return AgentModel(
      id: id,
      name: name,
      provider: provider,
      contextWindow: contextWindow,
      thinkingLevelMap: map
    )
  }
}

extension CachedMessageDTO {
  init(message: ChatMessage) {
    entryId = message.entryId
    role = message.role == .user ? "user" : "assistant"
    text = message.text
    codeLanguage = message.code?.language
    codeSource = message.code?.source
    thinkingSummary = message.thinking?.summary
    thinkingFull = message.thinking?.full
    thinkingSeconds = message.thinking?.seconds
    tools = message.tools.map(CachedToolDTO.init)
    terminal = message.terminal.map(CachedTerminalDTO.init)
    segments = message.segments.map(CachedSegmentDTO.init)
    tokens = message.tokens
    error = message.error
  }

  func asChatMessage() -> ChatMessage {
    let messageRole: ChatMessage.Role = role == "user" ? .user : .assistant
    var message = ChatMessage(entryId: entryId, role: messageRole, text: text, tokens: tokens)
    if let codeLanguage, let codeSource {
      message.code = (codeLanguage, codeSource)
    }
    if let thinkingFull {
      message.thinking = Thinking(
        summary: thinkingSummary ?? thinkingFull,
        truncated: thinkingSummary ?? thinkingFull,
        full: thinkingFull,
        seconds: thinkingSeconds ?? 0
      )
    }
    message.tools = tools.map(\.asToolUse)
    message.terminal = terminal.map(\.asTerminalRun)
    message.segments = segments.compactMap(\.asSegment)
    message.error = error
    message.isStreaming = false
    return message
  }
}

extension CachedToolDTO {
  init(_ tool: ToolUse) {
    switch tool.kind {
    case .mcp: kind = "mcp"
    case .skill: kind = "skill"
    case .builtin: kind = "builtin"
    }
    name = tool.name
    detail = tool.detail
    symbol = tool.symbol
    callId = tool.callId
  }

  var asToolUse: ToolUse {
    let toolKind: ToolKind =
      kind == "mcp" ? .mcp
      : kind == "skill" ? .skill
      : .builtin
    return ToolUse(kind: toolKind, name: name, detail: detail, symbol: symbol, callId: callId)
  }
}

extension CachedTerminalDTO {
  init(_ run: TerminalRun) {
    command = run.command
    output = run.output
    exitCode = run.exitCode
  }

  var asTerminalRun: TerminalRun {
    TerminalRun(command: command, output: output, exitCode: exitCode)
  }
}

extension CachedCommandRow {
  init(command: PiCommand, position: Int, serverKey: String) {
    self.name = command.name
    self.desc = command.description
    self.source = command.source
    self.location = command.location
    self.path = command.path
    self.position = position
    self.serverKey = serverKey
  }

  var asPiCommand: PiCommand {
    PiCommand(name: name, description: desc, source: source, location: location, path: path)
  }
}

extension CachedSegmentDTO {
  init(_ segment: ChatMessage.Segment) {
    switch segment {
    case .text(_, let text):
      kind = "text"
      self.text = text
      tool = nil
      terminal = nil
    case .tool(let toolUse):
      kind = "tool"
      text = nil
      tool = CachedToolDTO(toolUse)
      terminal = nil
    case .terminal(let run):
      kind = "terminal"
      text = nil
      tool = nil
      terminal = CachedTerminalDTO(run)
    }
  }

  var asSegment: ChatMessage.Segment? {
    switch kind {
    case "text":
      return .text(text: text ?? "")
    case "tool":
      guard let tool else { return nil }
      return .tool(tool.asToolUse)
    case "terminal":
      guard let terminal else { return nil }
      return .terminal(terminal.asTerminalRun)
    default:
      return nil
    }
  }
}
