//
//  RemoteFolderMock.swift
//  Pi Dev
//

import Foundation

final class MockFilesBrowser: FilesBrowserP {
  static let homePath = "/Users/preview"

  func listFiles(dir: String) async throws -> FilesListResponse {
    let path = Self.resolve(dir)
    guard let entries = Self.tree[path] else {
      throw RPCError(command: "list_files", message: "Directory not found: \(path)")
    }
    return FilesListResponse(success: true, path: path, entries: entries, error: nil)
  }

  private static func resolve(_ dir: String) -> String {
    let trimmed = dir.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed == "~" { return homePath }
    if trimmed.hasPrefix("~/") {
      return homePath + String(trimmed.dropFirst(1))
    }
    return trimmed
  }

  private static func folder(_ name: String, under dir: String) -> RemoteFileEntry {
    RemoteFileEntry(name: name, path: dir + "/" + name, type: .directory)
  }

  private static func file(_ name: String, under dir: String) -> RemoteFileEntry {
    RemoteFileEntry(name: name, path: dir + "/" + name, type: .file)
  }

  private static let tree: [String: [RemoteFileEntry]] = {
    let home = homePath
    let desktop = home + "/Desktop"
    let documents = home + "/Documents"
    let projects = documents + "/Projects"
    let appul = projects + "/appul"
    let website = projects + "/website"
    let downloads = home + "/Downloads"
    let pictures = home + "/Pictures"

    return [
      home: [
        folder("Desktop", under: home),
        folder("Documents", under: home),
        folder("Downloads", under: home),
        folder("Pictures", under: home),
      ],
      desktop: [
        file("screenshot.png", under: desktop),
        file("todo.txt", under: desktop),
      ],
      documents: [
        file("Notes.txt", under: documents),
        file("Resume.pdf", under: documents),
        folder("Projects", under: documents),
      ],
      projects: [
        folder("appul", under: projects),
        folder("website", under: projects),
      ],
      appul: [
        file("README.md", under: appul),
        file("Package.swift", under: appul),
        file("Root.swift", under: appul),
      ],
      website: [
        file("index.html", under: website),
        file("styles.css", under: website),
      ],
      downloads: [
        file("setup.dmg", under: downloads),
        file("photo.jpg", under: downloads),
        file("archive.zip", under: downloads),
      ],
      pictures: [
        file("vacation.jpg", under: pictures),
        file("headshot.png", under: pictures),
      ],
    ]
  }()
}
