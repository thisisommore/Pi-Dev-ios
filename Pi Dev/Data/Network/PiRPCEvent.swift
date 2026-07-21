//
//  PiRPCEvent.swift
//  Pi Dev
//

import Foundation

struct RPCResponse<T: Decodable>: Decodable {
  let id: String?
  let type: String
  let command: String?
  let success: Bool
  let error: String?
  let data: T?
}

struct RPCError: Error, LocalizedError {
  let command: String?
  let message: String

  var errorDescription: String? { message }
}

enum AgentEvent: @unchecked Sendable {
  case agentStart
  case agentEnd(messages: [AgentMessage])
  case turnStart
  case turnEnd(message: AgentMessage, toolResults: [AgentToolResult])
  case messageStart(message: AgentMessage)
  case messageUpdate(message: AgentMessage, delta: AssistantDelta)
  case messageEnd(message: AgentMessage)
  case toolExecutionStart(toolCallId: String, toolName: String, args: [String: Any])
  case toolExecutionUpdate(toolCallId: String, partialResult: AgentToolResult)
  case toolExecutionEnd(toolCallId: String, toolName: String, result: AgentToolResult, isError: Bool)
  case queueUpdate(steering: [String], followUp: [String])
  case compactionStart(reason: String)
  case compactionEnd(reason: String, result: CompactionResult?)
  case autoRetryStart(attempt: Int, maxAttempts: Int, delayMs: Int, errorMessage: String)
  case autoRetryEnd(success: Bool, attempt: Int)
  case extensionError(extensionPath: String, event: String, error: String)
  case unknown(raw: [String: Any])

  var debugName: String {
    switch self {
    case .agentStart: return "agent_start"
    case .agentEnd(let messages): return "agent_end(messages:\(messages.count))"
    case .turnStart: return "turn_start"
    case .turnEnd: return "turn_end"
    case .messageStart: return "message_start"
    case .messageUpdate(_, let delta): return "message_update(\(delta.debugName))"
    case .messageEnd: return "message_end"
    case .toolExecutionStart: return "tool_execution_start"
    case .toolExecutionUpdate: return "tool_execution_update"
    case .toolExecutionEnd: return "tool_execution_end"
    case .queueUpdate: return "queue_update"
    case .compactionStart: return "compaction_start"
    case .compactionEnd: return "compaction_end"
    case .autoRetryStart: return "auto_retry_start"
    case .autoRetryEnd: return "auto_retry_end"
    case .extensionError: return "extension_error"
    case .unknown(let raw): return "unknown(\(raw["type"] ?? "?"))"
    }
  }
}

enum AssistantDelta: Sendable {
  case start
  case textStart(contentIndex: Int)
  case textDelta(contentIndex: Int, delta: String)
  case textEnd(contentIndex: Int, content: String)
  case thinkingStart(contentIndex: Int)
  case thinkingDelta(contentIndex: Int, delta: String)
  case thinkingEnd(contentIndex: Int, content: String)
  case toolCallStart(contentIndex: Int)
  case toolCallDelta(contentIndex: Int, delta: String)
  case toolCallEnd(contentIndex: Int, toolCall: AgentToolCall)
  case done(reason: String)
  case error(reason: String)
  case unknown(type: String)

  var debugName: String {
    switch self {
    case .start: return "start"
    case .textStart(let i): return "text_start[\(i)]"
    case .textDelta(let i, _): return "text_delta[\(i)]"
    case .textEnd(let i, _): return "text_end[\(i)]"
    case .thinkingStart(let i): return "thinking_start[\(i)]"
    case .thinkingDelta(let i, _): return "thinking_delta[\(i)]"
    case .thinkingEnd(let i, _): return "thinking_end[\(i)]"
    case .toolCallStart(let i): return "toolcall_start[\(i)]"
    case .toolCallDelta(let i, _): return "toolcall_delta[\(i)]"
    case .toolCallEnd(let i, _): return "toolcall_end[\(i)]"
    case .done(let reason): return "done(\(reason))"
    case .error(let reason): return "error(\(reason))"
    case .unknown(let type): return "unknown(\(type))"
    }
  }
}

struct AgentMessage: Decodable, Sendable {
  let role: String?
  let content: MessageContent?
  let api: String?
  let provider: String?
  let model: String?
  let usage: AgentUsage?
  let stopReason: String?
  let timestamp: Int?
  let toolCallId: String?
  let toolName: String?
  let isError: Bool?
  var errorMessage: String? = nil

  enum MessageContent: Decodable, Sendable {
    case text(String)
    case blocks([ContentBlock])

    init(from decoder: Decoder) throws {
      let container = try decoder.singleValueContainer()
      if let string = try? container.decode(String.self) {
        self = .text(string)
      } else {
        let blocks = try container.decode([ContentBlock].self)
        self = .blocks(blocks)
      }
    }

    func textBlocks() -> [String] {
      switch self {
      case .text(let text): return [text]
      case .blocks(let blocks):
        return blocks.compactMap {
          if case .text(let text) = $0 { return text }
          return nil
        }
      }
    }

    func thinkingBlocks() -> [String] {
      switch self {
      case .text: return []
      case .blocks(let blocks):
        return blocks.compactMap {
          if case .thinking(let thinking) = $0 { return thinking }
          return nil
        }
      }
    }

    func toolCalls() -> [AgentToolCall] {
      switch self {
      case .text: return []
      case .blocks(let blocks):
        return blocks.compactMap {
          if case .toolCall(let call) = $0 { return call }
          return nil
        }
      }
    }
  }

  enum ContentBlock: Decodable, Sendable {
    case text(String)
    case thinking(String)
    case toolCall(AgentToolCall)
    case unknown(type: String)

    private enum CodingKeys: String, CodingKey { case type }

    init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      let type = try container.decode(String.self, forKey: .type)
      switch type {
      case "text":
        let text = try TextBlock(from: decoder)
        self = .text(text.text)
      case "thinking":
        let thinking = try ThinkingBlock(from: decoder)
        self = .thinking(thinking.thinking)
      case "toolCall":
        self = .toolCall(try AgentToolCall(from: decoder))
      default:
        self = .unknown(type: type)
      }
    }
  }

  struct TextBlock: Decodable, Sendable {
    let text: String
  }

  struct ThinkingBlock: Decodable, Sendable {
    let thinking: String
  }
}

struct AgentToolCall: Decodable, Sendable {
  let id: String?
  let name: String
  let arguments: [String: AnyCodable]?
}

struct AgentToolResult: Decodable, Sendable {
  let content: [ResultContent]?
  let details: [String: AnyCodable]?

  struct ResultContent: Decodable, Sendable {
    let type: String
    let text: String?
  }

  var textOutput: String {
    content?.compactMap { $0.text }.joined(separator: "\n") ?? ""
  }
}

struct AgentUsage: Decodable, Sendable {
  let input: Int?
  let output: Int?
  let cacheRead: Int?
  let cacheWrite: Int?
  let totalTokens: Int?
  let cost: AgentCost?
}

struct AgentCost: Decodable, Sendable {
  let input: Double?
  let output: Double?
  let cacheRead: Double?
  let cacheWrite: Double?
  let total: Double?
}

struct CompactionResult: Decodable, Sendable {
  let summary: String
  let firstKeptEntryId: String
  let tokensBefore: Int
  let estimatedTokensAfter: Int
}

struct AgentState: Decodable, Sendable {
  let model: AgentModel?
  let thinkingLevel: String?
  let isStreaming: Bool?
  let isCompacting: Bool?
  let steeringMode: String?
  let followUpMode: String?
  let sessionFile: String?
  let sessionId: String?
  let sessionName: String?
  let autoCompactionEnabled: Bool?
  let messageCount: Int?
  let pendingMessageCount: Int?
}

struct AgentModel: Decodable, Sendable {
  let id: String
  let name: String
  let provider: String?
  let contextWindow: Int?
  let thinkingLevelMap: [String: String?]?
}

struct AnyCodable: Decodable, @unchecked Sendable {
  let value: Any

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if let bool = try? container.decode(Bool.self) { value = bool }
    else if let int = try? container.decode(Int.self) { value = int }
    else if let double = try? container.decode(Double.self) { value = double }
    else if let string = try? container.decode(String.self) { value = string }
    else if let array = try? container.decode([AnyCodable].self) { value = array.map(\.value) }
    else if let dict = try? container.decode([String: AnyCodable].self) { value = dict.mapValues(\.value) }
    else { value = NSNull() }
  }
}

extension AgentEvent {
  init?(json: [String: Any]) {
    guard let type = json["type"] as? String else { return nil }
    switch type {
    case "agent_start":
      self = .agentStart
    case "agent_end":
      let messages = (json["messages"] as? [[String: Any]])?.compactMap { dict -> AgentMessage? in
        try? AgentMessage.decode(from: dict)
      } ?? []
      self = .agentEnd(messages: messages)
    case "turn_start":
      self = .turnStart
    case "turn_end":
      let message = (json["message"] as? [String: Any]).flatMap { try? AgentMessage.decode(from: $0) }
      let toolResults = (json["toolResults"] as? [[String: Any]])?.compactMap { dict -> AgentToolResult? in
        try? AgentToolResult.decode(from: dict)
      } ?? []
      self = .turnEnd(message: message ?? AgentMessage(role: nil, content: nil, api: nil, provider: nil, model: nil, usage: nil, stopReason: nil, timestamp: nil, toolCallId: nil, toolName: nil, isError: nil), toolResults: toolResults)
    case "message_start":
      let message = (json["message"] as? [String: Any]).flatMap { try? AgentMessage.decode(from: $0) }
      self = .messageStart(message: message ?? AgentMessage(role: nil, content: nil, api: nil, provider: nil, model: nil, usage: nil, stopReason: nil, timestamp: nil, toolCallId: nil, toolName: nil, isError: nil))
    case "message_update":
      let message = (json["message"] as? [String: Any]).flatMap { try? AgentMessage.decode(from: $0) }
      let delta = AssistantDelta(json: json["assistantMessageEvent"] as? [String: Any] ?? [:])
      self = .messageUpdate(message: message ?? AgentMessage(role: nil, content: nil, api: nil, provider: nil, model: nil, usage: nil, stopReason: nil, timestamp: nil, toolCallId: nil, toolName: nil, isError: nil), delta: delta)
    case "message_end":
      let message = (json["message"] as? [String: Any]).flatMap { try? AgentMessage.decode(from: $0) }
      self = .messageEnd(message: message ?? AgentMessage(role: nil, content: nil, api: nil, provider: nil, model: nil, usage: nil, stopReason: nil, timestamp: nil, toolCallId: nil, toolName: nil, isError: nil))
    case "tool_execution_start":
      self = .toolExecutionStart(toolCallId: json["toolCallId"] as? String ?? "", toolName: json["toolName"] as? String ?? "", args: json["args"] as? [String: Any] ?? [:])
    case "tool_execution_update":
      let result = (json["partialResult"] as? [String: Any]).flatMap { try? AgentToolResult.decode(from: $0) }
      self = .toolExecutionUpdate(toolCallId: json["toolCallId"] as? String ?? "", partialResult: result ?? AgentToolResult(content: nil, details: nil))
    case "tool_execution_end":
      let result = (json["result"] as? [String: Any]).flatMap { try? AgentToolResult.decode(from: $0) }
      self = .toolExecutionEnd(toolCallId: json["toolCallId"] as? String ?? "", toolName: json["toolName"] as? String ?? "", result: result ?? AgentToolResult(content: nil, details: nil), isError: json["isError"] as? Bool ?? false)
    case "queue_update":
      self = .queueUpdate(steering: json["steering"] as? [String] ?? [], followUp: json["followUp"] as? [String] ?? [])
    case "compaction_start":
      self = .compactionStart(reason: json["reason"] as? String ?? "")
    case "compaction_end":
      let result = (json["result"] as? [String: Any]).flatMap { try? CompactionResult.decode(from: $0) }
      self = .compactionEnd(reason: json["reason"] as? String ?? "", result: result)
    case "auto_retry_start":
      self = .autoRetryStart(attempt: json["attempt"] as? Int ?? 0, maxAttempts: json["maxAttempts"] as? Int ?? 0, delayMs: json["delayMs"] as? Int ?? 0, errorMessage: json["errorMessage"] as? String ?? "")
    case "auto_retry_end":
      self = .autoRetryEnd(success: json["success"] as? Bool ?? false, attempt: json["attempt"] as? Int ?? 0)
    case "extension_error":
      self = .extensionError(extensionPath: json["extensionPath"] as? String ?? "", event: json["event"] as? String ?? "", error: json["error"] as? String ?? "")
    default:
      self = .unknown(raw: json)
    }
  }
}

extension AssistantDelta {
  init(json: [String: Any]) {
    guard let type = json["type"] as? String else {
      self = .unknown(type: "")
      return
    }
    let index = json["contentIndex"] as? Int ?? 0
    switch type {
    case "start": self = .start
    case "text_start": self = .textStart(contentIndex: index)
    case "text_delta": self = .textDelta(contentIndex: index, delta: json["delta"] as? String ?? "")
    case "text_end": self = .textEnd(contentIndex: index, content: json["content"] as? String ?? "")
    case "thinking_start": self = .thinkingStart(contentIndex: index)
    case "thinking_delta": self = .thinkingDelta(contentIndex: index, delta: json["delta"] as? String ?? "")
    case "thinking_end": self = .thinkingEnd(contentIndex: index, content: json["content"] as? String ?? "")
    case "toolcall_start": self = .toolCallStart(contentIndex: index)
    case "toolcall_delta": self = .toolCallDelta(contentIndex: index, delta: json["delta"] as? String ?? "")
    case "toolcall_end":
      let call = (json["toolCall"] as? [String: Any]).flatMap { try? AgentToolCall.decode(from: $0) }
      self = .toolCallEnd(contentIndex: index, toolCall: call ?? AgentToolCall(id: nil, name: "", arguments: nil))
    case "done": self = .done(reason: json["reason"] as? String ?? "stop")
    case "error": self = .error(reason: json["reason"] as? String ?? "error")
    default: self = .unknown(type: type)
    }
  }
}

private extension Decodable {
  static func decode(from dictionary: [String: Any]) throws -> Self {
    let data = try JSONSerialization.data(withJSONObject: dictionary)
    return try JSONDecoder().decode(Self.self, from: data)
  }
}
