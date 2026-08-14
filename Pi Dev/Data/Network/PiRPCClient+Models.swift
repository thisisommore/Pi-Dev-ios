//
//  PiRPCClient+Models.swift
//  Pi Dev
//

import Foundation

struct AgentMessagesResponse: Decodable, Sendable {
  let messages: [AgentMessage]
}

struct AgentEntriesResponse: Decodable, Sendable {
  let entries: [AgentEntry]
}

struct AgentEntry: Decodable, Sendable {
  let type: String
  let id: String?
  let parentId: String?
  let timestamp: String?
  let message: AgentMessage?
}

struct RerunResponse: Decodable, Sendable {
  let success: Bool
  let message: String?
  let entryId: String?
}

struct PromptResponse: Decodable, Sendable {
  let entryId: String?
}

struct LastTextResponse: Decodable, Sendable {
  let text: String?
}

struct AvailableModelsResponse: Decodable, Sendable {
  let models: [AgentModel]
}

struct SessionsResponse: Decodable, Sendable {
  let sessions: [SessionInfo]
}

struct SessionInfo: Identifiable, Decodable, Sendable, Equatable {
  let path: String
  let id: String
  let cwd: String
  let name: String?
  let created: String
  let modified: String
  let messageCount: Int
  let firstMessage: String?
  let allMessagesText: String?
}

struct EmptyResponse: Decodable, Sendable {}

struct FilesListResponse: Decodable, Sendable {
  let success: Bool
  let path: String?
  let entries: [RemoteFileEntry]?
  let error: String?
}

struct RemoteFileEntry: Identifiable, Decodable, Sendable, Hashable {
  var id: String { path }
  let name: String
  let path: String
  let type: Kind

  enum Kind: String, Decodable, Sendable {
    case directory
    case file
    case other
  }

  var isFolder: Bool { type == .directory }
}

