//
//  PiRPCClient.swift
//  Pi Dev
//

import Foundation

/// HTTP JSON-RPC client for the π coding-agent server at localhost:3000.
///
/// The server is expected to accept POST requests whose body is a π RPC command
/// object (e.g. `{ "type": "prompt", "message": "..." }`) and return the
/// matching `response` object.  Streaming events can be consumed via SSE on
/// `/events` or by polling `get_last_assistant_text` when SSE is unavailable.
final class PiRPCClient {
  let baseURL: URL
  private let urlSession: URLSession
  private var activeTask: Task<Void, Never>?
  private let lock = NSLock()

  init(baseURL: URL = URL(string: "http://localhost:3000")!, urlSession: URLSession = .shared) {
    self.baseURL = baseURL
    self.urlSession = urlSession
  }

  deinit {
    lock.withLock { activeTask }?.cancel()
  }

  private func setActiveTask(_ task: Task<Void, Never>?) {
    lock.withLock { activeTask = task }
  }

  private func cancelActiveTask() {
    lock.withLock { activeTask }?.cancel()
    lock.withLock { activeTask = nil }
  }

  // MARK: - Typed commands

  func prompt(message: String) async throws -> RPCResponse<EmptyResponse> {
    try await send(command: ["type": "prompt", "message": message])
  }

  func rerun() async throws {
    let rerunURL = baseURL.appendingPathComponent("rerun")
    var request = URLRequest(url: rerunURL)
    request.httpMethod = "POST"

    let (data, response) = try await urlSession.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
      let body = String(data: data, encoding: .utf8) ?? ""
      throw RPCError(command: "rerun", message: "HTTP error: \(body)")
    }
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

  func getLastAssistantText() async throws -> RPCResponse<LastTextResponse> {
    try await send(command: ["type": "get_last_assistant_text"])
  }

  func setThinkingLevel(_ level: ThinkingLevel) async throws -> RPCResponse<EmptyResponse> {
    try await send(command: ["type": "set_thinking_level", "level": level.rawValue.lowercased()])
  }

  func setModel(provider: String, modelId: String) async throws -> RPCResponse<AgentModel> {
    try await send(command: ["type": "set_model", "provider": provider, "modelId": modelId])
  }

  func getAvailableModels() async throws -> RPCResponse<AvailableModelsResponse> {
    try await send(command: ["type": "get_available_models"])
  }

  // MARK: - Session REST endpoints

  func listSessions() async throws -> [SessionInfo] {
    let sessionsURL = baseURL.appendingPathComponent("sessions")
    var request = URLRequest(url: sessionsURL)
    request.httpMethod = "GET"

    let (data, response) = try await urlSession.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
      let body = String(data: data, encoding: .utf8) ?? ""
      throw RPCError(command: "list_sessions", message: "HTTP error: \(body)")
    }

    let decoded = try JSONDecoder().decode(SessionsResponse.self, from: data)
    return decoded.sessions
  }

  func switchSession(path: String) async throws -> RPCResponse<EmptyResponse> {
    try await send(command: ["type": "switch_session", "sessionPath": path])
  }

  func newSession() async throws -> RPCResponse<EmptyResponse> {
    try await send(command: ["type": "new_session"])
  }

  // MARK: - Generic request

  func send<T: Decodable>(command: [String: Any]) async throws -> RPCResponse<T> {
    let rpcURL = baseURL.appendingPathComponent("rpc")
    var request = URLRequest(url: rpcURL)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
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

  // MARK: - Streaming

  /// Sends a prompt and streams agent events back.
  ///
  /// First tries Server-Sent Events on `baseURL/events`.  If the server does not
  /// support SSE, falls back to polling `get_last_assistant_text` and
  /// `get_messages` until the agent stops streaming.
  func streamEvents(forPrompt promptText: String) -> AsyncStream<AgentEvent> {
    print("[PiRPCClient] streamEvents start for prompt: \(promptText.prefix(40))")
    let stream = AsyncStream<AgentEvent> { continuation in
      let task = Task { [weak self] in
        guard let self else {
          print("[PiRPCClient] streamEvents self deallocated, finishing")
          continuation.finish()
          return
        }

        // Start reading SSE first so we don't miss events that arrive while
        // the prompt request is in flight.
        let sseTask = Task { [weak self] in
          guard let self else {
            print("[PiRPCClient] readSSE self deallocated")
            return false
          }
          return await self.readSSE(into: continuation)
        }

        do {
          print("[PiRPCClient] sending prompt RPC")
          _ = try await self.prompt(message: promptText)
          print("[PiRPCClient] prompt RPC accepted")
        } catch {
          print("[PiRPCClient] prompt RPC failed: \(error.localizedDescription)")
          sseTask.cancel()
          continuation.yield(.extensionError(extensionPath: "PiRPCClient", event: "prompt", error: error.localizedDescription))
          continuation.finish()
          return
        }

        let sseWorked = await sseTask.value
        print("[PiRPCClient] SSE task returned worked=\(sseWorked)")
        if !sseWorked {
          print("[PiRPCClient] falling back to polling")
          await self.pollUntilDone(into: continuation)
        }
        print("[PiRPCClient] finishing stream")
        continuation.finish()
      }

      self.setActiveTask(task)
      continuation.onTermination = { @Sendable _ in
        print("[PiRPCClient] stream terminated, cancelling task")
        task.cancel()
      }
    }
    return stream
  }

  /// Re-runs the last user turn and streams agent events back.
  ///
  /// Uses the same SSE/polling fallback as `streamEvents(forPrompt:)`.
  func streamRerunEvents() -> AsyncStream<AgentEvent> {
    print("[PiRPCClient] streamRerunEvents start")
    let stream = AsyncStream<AgentEvent> { continuation in
      let task = Task { [weak self] in
        guard let self else {
          print("[PiRPCClient] streamRerunEvents self deallocated, finishing")
          continuation.finish()
          return
        }

        // Start reading SSE first so we don't miss events that arrive while
        // the rerun request is in flight.
        let sseTask = Task { [weak self] in
          guard let self else {
            print("[PiRPCClient] readSSE self deallocated")
            return false
          }
          return await self.readSSE(into: continuation)
        }

        do {
          print("[PiRPCClient] sending rerun request")
          try await self.rerun()
          print("[PiRPCClient] rerun request accepted")
        } catch {
          print("[PiRPCClient] rerun request failed: \(error.localizedDescription)")
          sseTask.cancel()
          continuation.yield(.extensionError(extensionPath: "PiRPCClient", event: "rerun", error: error.localizedDescription))
          continuation.finish()
          return
        }

        let sseWorked = await sseTask.value
        print("[PiRPCClient] SSE task returned worked=\(sseWorked)")
        if !sseWorked {
          print("[PiRPCClient] falling back to polling")
          await self.pollUntilDone(into: continuation)
        }
        print("[PiRPCClient] finishing stream")
        continuation.finish()
      }

      self.setActiveTask(task)
      continuation.onTermination = { @Sendable _ in
        print("[PiRPCClient] stream terminated, cancelling task")
        task.cancel()
      }
    }
    return stream
  }

  private func readSSE(into continuation: AsyncStream<AgentEvent>.Continuation) async -> Bool {
    let eventsURL = baseURL.appendingPathComponent("events")
    var request = URLRequest(url: eventsURL)
    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
    print("[PiRPCClient] readSSE connecting to \(eventsURL)")

    do {
      let (bytes, response) = try await urlSession.bytes(for: request)
      guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        print("[PiRPCClient] readSSE non-success status: \(status)")
        return false
      }
      print("[PiRPCClient] readSSE connected (status \((response as? HTTPURLResponse)?.statusCode ?? -1))")

      var dataLines: [String] = []
      var eventName: String?
      var lineCount = 0

      var shouldStop = false

      func flushPendingEvent() {
        guard !dataLines.isEmpty else {
          eventName = nil
          return
        }
        let payload = dataLines.joined(separator: "\n")
        print("[PiRPCClient] readSSE parsed event='\(eventName ?? "")' payload=\(payload.prefix(200))")
        if eventName == "pi",
           let data = payload.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let event = AgentEvent(json: json) {
          print("[PiRPCClient] readSSE yielding event: \(event.debugName)")
          continuation.yield(event)
          if case .agentEnd = event {
            print("[PiRPCClient] readSSE agent_end received, closing SSE reader")
            shouldStop = true
          }
        } else {
          print("[PiRPCClient] readSSE dropped payload (event='\(eventName ?? "")', parse failed)")
        }
        dataLines = []
        eventName = nil
      }

      for try await line in bytes.lines {
        lineCount += 1
        if lineCount <= 10 || lineCount % 20 == 0 {
          print("[PiRPCClient] readSSE line #\(lineCount): '\(line.prefix(120))'")
        }
        if Task.isCancelled {
          print("[PiRPCClient] readSSE cancelled after \(lineCount) lines")
          return true
        }

        if line.hasPrefix("event: ") {
          // A new event starts; flush any previous event first.
          flushPendingEvent()
          if shouldStop { return true }
          eventName = String(line.dropFirst(7)).trimmingCharacters(in: .whitespaces)
        } else if line.hasPrefix("data: ") {
          dataLines.append(String(line.dropFirst(6)))
        } else if line.isEmpty {
          // Some SSE streams separate events with blank lines.
          flushPendingEvent()
          if shouldStop { return true }
        }
      }
      flushPendingEvent()
      print("[PiRPCClient] readSSE stream ended after \(lineCount) lines")
      return true
    } catch {
      print("[PiRPCClient] readSSE error: \(error.localizedDescription)")
      return false
    }
  }

  private func pollUntilDone(into continuation: AsyncStream<AgentEvent>.Continuation) async {
    continuation.yield(.agentStart)
    continuation.yield(.messageStart(message: AgentMessage(role: nil, content: nil, api: nil, provider: nil, model: nil, usage: nil, stopReason: nil, timestamp: nil, toolCallId: nil, toolName: nil, isError: nil)))

    var previousText: String? = nil
    var settledTicks = 0
    let maxSettledTicks = 10

    while !Task.isCancelled {
      do {
        let lastResponse = try await getLastAssistantText()
        let currentText = lastResponse.data?.text

        if let currentText, currentText != previousText {
          continuation.yield(.messageUpdate(
            message: AgentMessage(role: nil, content: nil, api: nil, provider: nil, model: nil, usage: nil, stopReason: nil, timestamp: nil, toolCallId: nil, toolName: nil, isError: nil),
            delta: .textDelta(contentIndex: 0, delta: String(currentText.dropFirst(previousText?.count ?? 0)))
          ))
          previousText = currentText
          settledTicks = 0
        } else {
          settledTicks += 1
        }

        let state = try await getState()
        if state.data?.isStreaming == false, settledTicks >= maxSettledTicks {
          let messages = try await getMessages()
          if let assistant = messages.data?.messages.last(where: { $0.role == "assistant" }) {
            continuation.yield(.messageEnd(message: assistant))
          }
          continuation.yield(.agentEnd(messages: messages.data?.messages ?? []))
          break
        }
      } catch {
        continuation.yield(.extensionError(extensionPath: "PiRPCClient", event: "poll", error: error.localizedDescription))
      }

      try? await Task.sleep(for: .milliseconds(200))
    }
  }

  func cancel() {
    cancelActiveTask()
  }
}

struct AgentMessagesResponse: Decodable, Sendable {
  let messages: [AgentMessage]
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

struct SessionInfo: Identifiable, Decodable, Sendable {
  let path: String
  let id: String
  let cwd: String
  let created: String
  let modified: String
  let messageCount: Int
  let firstMessage: String?
  let allMessagesText: String?
}

struct EmptyResponse: Decodable, Sendable {}

private extension NSLock {
  func withLock<T>(_ block: () -> T) -> T {
    lock()
    defer { unlock() }
    return block()
  }
}
