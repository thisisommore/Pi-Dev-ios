//
//  PiCommand.swift
//  Pi Dev
//

import Foundation

/// A π RPC command returned by `get_commands`.
///
/// Mirrors the RPC documentation:
/// ```
/// {
///   "name": "session-name",
///   "description": "Set or clear session name",
///   "source": "extension",
///   "path": "/home/user/.pi/agent/extensions/session.ts"
/// }
/// ```
/// or
/// ```
/// {
///   "name": "skill:brave-search",
///   "description": "Web search via Brave API",
///   "source": "skill",
///   "location": "user",
///   "path": "/home/user/.pi/agent/skills/brave-search/SKILL.md"
/// }
/// ```
struct PiCommand: Decodable, Identifiable, Sendable, Equatable, Hashable {
  let name: String
  let description: String?
  let source: String
  let location: String?
  let path: String?

  var id: String { name }

  /// "/name" as invoked in the prompt box
  var invocation: String { "/" + name }

  var sourceLabel: String {
    switch source {
    case "extension": return "ext"
    case "skill": return "skill"
    case "prompt": return "prompt"
    default: return source
    }
  }

  var symbol: String {
    switch source {
    case "skill": return "sparkles"
    case "prompt": return "doc.text"
    case "extension": return "puzzlepiece.extension"
    default: return "command"
    }
  }

  var sourceColor: String {
    // Used as a hint for tinting; caller maps to actual Color
    source
  }
}

/// Wrapper for `get_commands` response data.
struct CommandsResponse: Decodable, Sendable {
  let commands: [PiCommand]
}
