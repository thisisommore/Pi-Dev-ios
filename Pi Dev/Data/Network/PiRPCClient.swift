//
//  PiRPCClient.swift
//  Pi Dev
//

import Foundation

/// HTTP JSON-RPC client for the π coding-agent server.
///
/// The server is expected to accept POST requests whose body is a π RPC command
/// object (e.g. `{ "type": "prompt", "message": "..." }`) and return the
/// matching `response` object.  Streaming events can be consumed via SSE on
/// `/events` or by polling `get_last_assistant_text` when SSE is unavailable.
final class PiRPCClient {
  let baseURL: URL?
  let authToken: String
  let urlSession: URLSession
  private var activeTask: Task<Void, Never>?
  private let lock = NSLock()

  init(baseURL: URL? = PiRPCClient.configuredBaseURL(), authToken: String = PiRPCClient.configuredAuthToken(), urlSession: URLSession = .shared) {
    self.baseURL = baseURL
    self.authToken = authToken
    self.urlSession = urlSession
  }

  private static func configuredBaseURL() -> URL? {
    let stored = UserDefaults.standard.string(forKey: "piServerBaseURL")
    let raw = stored?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if raw.isEmpty { return nil }
    // Normalize bare hostnames like "pi.sh.ommore.xyz" → https://...
    let normalized: String = {
      if raw.hasPrefix("http://") || raw.hasPrefix("https://") { return raw }
      return "https://" + raw
    }()
    if let url = URL(string: normalized), url.host != nil {
      return url
    }
    // Fall back to raw if it at least parses (legacy)
    if let url = URL(string: raw), url.host != nil {
      return url
    }
    return nil
  }

  private static func configuredAuthToken() -> String {
    UserDefaults.standard.string(forKey: "piAuthToken")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
  }

  /// Current values from UserDefaults (not the snapshot at init) — use for
  /// per-request auth/host to handle server switch without app restart.
  /// Returns nil if no URL is configured — caller should fail instead of using localhost.
  private var currentBaseURL: URL? {
    if let cfg = Self.configuredBaseURL() { return cfg }
    return baseURL
  }
  private var currentAuthToken: String { Self.configuredAuthToken() }

  func requireBaseURL() throws -> URL {
    guard let url = currentBaseURL else {
      throw RPCError(command: nil, message: "No server URL configured")
    }
    return url
  }

  func configureAuth(for request: inout URLRequest) {
    let token = currentAuthToken.isEmpty ? authToken : currentAuthToken
    if !token.isEmpty {
      request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    } else if !authToken.isEmpty {
      request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
    }
  }

  deinit {
    lock.withLock { activeTask }?.cancel()
  }

  func setActiveTask(_ task: Task<Void, Never>?) {
    // Cancel previous streaming task before overwriting — prevents two
    // concurrent streams fighting over the same SSE connection and
    // polluting each other's AsyncStream.
    let previous: Task<Void, Never>? = lock.withLock {
      let prev = activeTask
      activeTask = task
      return prev
    }
    previous?.cancel()
  }

  private func cancelActiveTask() {
    let task: Task<Void, Never>? = lock.withLock {
      let t = activeTask
      activeTask = nil
      return t
    }
    task?.cancel()
  }

  // MARK: - Typed commands

  func prompt(message: String, repo: String? = nil) async throws -> RPCResponse<PromptResponse> {
    var command: [String: Any] = ["type": "prompt", "message": message]
    if let repo { command["repo"] = repo }
    return try await send(command: command)
  }

  func rerun(message: String? = nil, entryId: String? = nil) async throws -> String? {
    let rerunURL = try requireBaseURL().appendingPathComponent("rerun")
    var request = URLRequest(url: rerunURL)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    configureAuth(for: &request)

    var body: [String: Any] = [:]
    if let message { body["message"] = message }
    if let entryId { body["entryId"] = entryId }
    if !body.isEmpty {
      request.httpBody = try JSONSerialization.data(withJSONObject: body)
    }

    let (data, response) = try await urlSession.data(for: request)
    let responseBody = String(data: data, encoding: .utf8) ?? ""
    guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
      throw RPCError(command: "rerun", message: "HTTP error: \(responseBody)")
    }

    let rerunResponse = try? JSONDecoder().decode(RerunResponse.self, from: data)
    return rerunResponse?.entryId
  }

  func steer(message: String) async throws -> RPCResponse<EmptyResponse> {
    try await send(command: ["type": "steer", "message": message])
  }

  func abort() async throws -> RPCResponse<EmptyResponse> {
    try await send(command: ["type": "abort"])
  }

  func getState() async throws -> RPCResponse<AgentState> {
    try await send(command: ["type": "get_state"])
  }

  func getMessages() async throws -> RPCResponse<AgentMessagesResponse> {
    try await send(command: ["type": "get_messages"])
  }

  func getEntries() async throws -> RPCResponse<AgentEntriesResponse> {
    try await send(command: ["type": "get_entries"])
  }

  func getLastAssistantText() async throws -> RPCResponse<LastTextResponse> {
    try await send(command: ["type": "get_last_assistant_text"])
  }

  func setThinkingLevel(_ level: ThinkingLevel) async throws -> RPCResponse<EmptyResponse> {
    try await send(command: ["type": "set_thinking_level", "level": level.id])
  }

  func setModel(provider: String, modelId: String) async throws -> RPCResponse<AgentModel> {
    try await send(command: ["type": "set_model", "provider": provider, "modelId": modelId])
  }

  func getAvailableModels() async throws -> RPCResponse<AvailableModelsResponse> {
    try await send(command: ["type": "get_available_models"])
  }

  func getCommands() async throws -> RPCResponse<CommandsResponse> {
    try await send(command: ["type": "get_commands"])
  }

  // MARK: - Health check

  /// Validates the configured base URL and auth token by calling `get_state`.
  /// Returns `.success` if the server responds with a valid RPC success response,
  /// or `.failure` with the underlying error otherwise.
  func healthCheck() async -> Result<Void, Error> {
    do {
      _ = try await getState()
      return .success(())
    } catch {
      return .failure(error)
    }
  }

  // MARK: - Session REST endpoints

  func listSessions() async throws -> [SessionInfo] {
    let sessionsURL = try requireBaseURL().appendingPathComponent("sessions")
    var request = URLRequest(url: sessionsURL)
    request.httpMethod = "GET"
    configureAuth(for: &request)

    let (data, response) = try await urlSession.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
      let body = String(data: data, encoding: .utf8) ?? ""
      throw RPCError(command: "list_sessions", message: "HTTP error: \(body)")
    }

    let decoded = try JSONDecoder().decode(SessionsResponse.self, from: data)
    return decoded.sessions
  }

  func listFiles(dir: String) async throws -> FilesListResponse {
    let filesURL = try requireBaseURL().appendingPathComponent("files")
    var components = URLComponents(url: filesURL, resolvingAgainstBaseURL: false)
    components?.queryItems = [URLQueryItem(name: "dir", value: dir)]
    guard let url = components?.url else {
      throw RPCError(command: "list_files", message: "Invalid directory path")
    }

    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    configureAuth(for: &request)

    let (data, response) = try await urlSession.data(for: request)
    let decoded = try? JSONDecoder().decode(FilesListResponse.self, from: data)
    guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
      throw RPCError(command: "list_files", message: decoded?.error ?? "HTTP error")
    }
    guard let decoded, decoded.success else {
      throw RPCError(command: "list_files", message: decoded?.error ?? "Unknown error")
    }
    return decoded
  }

  func switchSession(path: String) async throws -> RPCResponse<EmptyResponse> {
    try await send(command: ["type": "switch_session", "sessionPath": path])
  }

  func newSession() async throws -> RPCResponse<EmptyResponse> {
    try await send(command: ["type": "new_session"])
  }

  func setSessionName(_ name: String) async throws -> RPCResponse<EmptyResponse> {
    try await send(command: ["type": "set_session_name", "name": name])
  }

  // MARK: - Generic request

  func send<T: Decodable>(command: [String: Any]) async throws -> RPCResponse<T> {
    let rpcURL = try requireBaseURL().appendingPathComponent("rpc")
    var request = URLRequest(url: rpcURL)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    configureAuth(for: &request)
    request.httpBody = try JSONSerialization.data(withJSONObject: command)

    let (data, response) = try await urlSession.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
      let body = String(data: data, encoding: .utf8) ?? ""
      throw RPCError(command: command["type"] as? String, message: "HTTP error: \(body)")
    }

    let decoded = try JSONDecoder().decode(RPCResponse<T>.self, from: data)
    guard decoded.success else {
      throw RPCError(command: decoded.command ?? command["type"] as? String, message: decoded.error ?? "Unknown RPC error")
    }
    return decoded
  }

  func cancel() {
    cancelActiveTask()
  }
}

extension PiRPCClient: PiRPCP {}

private extension NSLock {
  func withLock<T>(_ block: () -> T) -> T {
    lock()
    defer { unlock() }
    return block()
  }
}
