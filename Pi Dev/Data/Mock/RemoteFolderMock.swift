//
//  RemoteFolderMock.swift
//  Pi Dev
//

import Foundation

struct RemoteEntry: Identifiable, Hashable {
  let id: String
  let name: String
  let isFolder: Bool
  let children: [RemoteEntry]

  init(name: String, isFolder: Bool, children: [RemoteEntry] = []) {
    self.id = name
    self.name = name
    self.isFolder = isFolder
    self.children = children
  }

  static func folder(_ name: String, _ children: [RemoteEntry]) -> RemoteEntry {
    RemoteEntry(name: name, isFolder: true, children: children)
  }

  static func file(_ name: String) -> RemoteEntry {
    RemoteEntry(name: name, isFolder: false)
  }
}

enum RemoteFolderMock {
  static let homeName = "Home"

  static let home = RemoteEntry.folder(homeName, [
    .folder("Desktop", [
      .file("screenshot.png"),
      .file("todo.txt"),
    ]),
    .folder("Documents", [
      .file("Notes.txt"),
      .file("Resume.pdf"),
      .folder("Projects", [
        .folder("appul", [
          .file("README.md"),
          .file("Package.swift"),
          .file("Root.swift"),
        ]),
        .folder("website", [
          .file("index.html"),
          .file("styles.css"),
        ]),
      ]),
    ]),
    .folder("Downloads", [
      .file("setup.dmg"),
      .file("photo.jpg"),
      .file("archive.zip"),
    ]),
    .folder("Pictures", [
      .file("vacation.jpg"),
      .file("headshot.png"),
    ]),
  ])
}
