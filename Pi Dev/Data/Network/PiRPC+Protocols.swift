//
//  PiRPC+Protocols.swift
//  Pi Dev
//

import Foundation

/// Shared protocol for the π JSON-RPC client.
/// Stores should depend on `PiRPCP` so `PiRPCClient` can be replaced with a mock
/// in previews and tests without changing call sites.
protocol PiRPCP: AnyObject {
  func prompt(message: String, repo: String?) async throws -> RPCResponse<PromptResponse>
  func rerun(message: String?, entryId: String?) async throws -> String?
  func steer(message: String) async throws -> RPCResponse<EmptyResponse>
  func abort() async throws -> RPCResponse<EmptyResponse>
  func getState() async throws -> RPCResponse<AgentState>
  func getMessages() async throws -> RPCResponse<AgentMessagesResponse>
  func getEntries() async throws -> RPCResponse<AgentEntriesResponse>
  func getLastAssistantText() async throws -> RPCResponse<LastTextResponse>
  func setThinkingLevel(_ level: ThinkingLevel) async throws -> RPCResponse<EmptyResponse>
  func setModel(provider: String, modelId: String) async throws -> RPCResponse<AgentModel>
  func getAvailableModels() async throws -> RPCResponse<AvailableModelsResponse>
  func getCommands() async throws -> RPCResponse<CommandsResponse>
  func healthCheck() async -> Result<Void, Error>
  func listSessions() async throws -> [SessionInfo]
  func listFiles(dir: String) async throws -> FilesListResponse
  func switchSession(path: String) async throws -> RPCResponse<EmptyResponse>
  func newSession() async throws -> RPCResponse<EmptyResponse>
  func setSessionName(_ name: String) async throws -> RPCResponse<EmptyResponse>
  func streamEvents(
    forPrompt promptText: String,
    repo: String?,
    onEntryId: (@MainActor (String?) -> Void)?
  ) -> AsyncStream<AgentEvent>
  func streamRerunEvents(
    message: String?,
    entryId: String?,
    onEntryId: (@MainActor (String?) -> Void)?
  ) -> AsyncStream<AgentEvent>
  func cancel()
}
