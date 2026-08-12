//
//  PiRPCClient+Stream.swift
//  Pi Dev
//

import Foundation

extension PiRPCClient {
  /// Sends a prompt and streams agent events back.
  ///
  /// First tries Server-Sent Events on `baseURL/events`.  If the server does not
  /// support SSE, falls back to polling `get_last_assistant_text` and
  /// `get_messages` until the agent stops streaming.
  func streamEvents(forPrompt promptText: String, repo: String? = nil, onEntryId: (@MainActor (String?) -> Void)? = nil) -> AsyncStream<AgentEvent> {
    let stream = AsyncStream<AgentEvent> { continuation in
      let task = Task { [weak self] in
        guard let self else {
          continuation.finish()
          return
        }

        // Start reading SSE first so we don't miss events that arrive while
        // the prompt request is in flight.
        let sseTask = Task { [weak self] in
          guard let self else {
            return false
          }
          return await self.readSSE(into: continuation)
        }

        do {
          let response = try await self.prompt(message: promptText, repo: repo)
          if let onEntryId {
            await onEntryId(response.data?.entryId)
          }
        } catch {
          sseTask.cancel()
          continuation.yield(.extensionError(extensionPath: "PiRPCClient", event: "prompt", error: error.localizedDescription))
          continuation.finish()
          return
        }

        let sseWorked = await sseTask.value
        if !sseWorked {
          await self.pollUntilDone(into: continuation)
        }
        continuation.finish()
      }

      self.setActiveTask(task)
      continuation.onTermination = { @Sendable _ in
        task.cancel()
      }
    }
    return stream
  }

  /// Re-runs the last user turn and streams agent events back.
  ///
  /// Uses the same SSE/polling fallback as `streamEvents(forPrompt:)`.
  func streamRerunEvents(message: String? = nil, entryId: String? = nil, onEntryId: (@MainActor (String?) -> Void)? = nil) -> AsyncStream<AgentEvent> {
    let stream = AsyncStream<AgentEvent> { continuation in
      let task = Task { [weak self] in
        guard let self else {
          continuation.finish()
          return
        }

        // Start reading SSE first so we don't miss events that arrive while
        // the rerun request is in flight.
        let sseTask = Task { [weak self] in
          guard let self else {
            return false
          }
          return await self.readSSE(into: continuation)
        }

        do {
          let returnedEntryId = try await self.rerun(message: message, entryId: entryId)
          if let onEntryId {
            await onEntryId(returnedEntryId)
          }
        } catch {
          sseTask.cancel()
          continuation.yield(.extensionError(extensionPath: "PiRPCClient", event: "rerun", error: error.localizedDescription))
          continuation.finish()
          return
        }

        let sseWorked = await sseTask.value
        if !sseWorked {
          await self.pollUntilDone(into: continuation)
        }
        continuation.finish()
      }

      self.setActiveTask(task)
      continuation.onTermination = { @Sendable _ in
        task.cancel()
      }
    }
    return stream
  }

  private func readSSE(into continuation: AsyncStream<AgentEvent>.Continuation) async -> Bool {
    guard let eventsURL = try? requireBaseURL().appendingPathComponent("events") else { return false }
    var request = URLRequest(url: eventsURL)
    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
    configureAuth(for: &request)

    do {
      let (bytes, response) = try await urlSession.bytes(for: request)
      guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
        return false
      }

      var dataLines: [String] = []
      var eventName: String?
      var shouldStop = false

      func flushPendingEvent() {
        guard !dataLines.isEmpty else {
          eventName = nil
          return
        }
        let payload = dataLines.joined(separator: "\n")
        if eventName == "pi",
           let data = payload.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let event = AgentEvent(json: json) {
          continuation.yield(event)
          if case .agentEnd = event {
            shouldStop = true
          }
        }
        dataLines = []
        eventName = nil
      }

      for try await line in bytes.lines {
        if Task.isCancelled {
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
      return true
    } catch {
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

}
