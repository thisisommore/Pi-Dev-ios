//
//  FolderPickerSheet.swift
//  Pi Dev Mac
//

import SwiftUI

struct FolderPickerSheet: View {
    var onOpen: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var dirStack: [String] = [MockFolderTree.home]
    @State private var layout: FolderLayout = .grid

    private var currentPath: String { dirStack.last ?? MockFolderTree.home }
    private var items: [MockFolderEntry] { MockFolderTree.entries(in: currentPath) }

    private var titleName: String {
        dirStack.count == 1 ? "Home" : (currentPath as NSString).lastPathComponent
    }

    private var folderBlue: Color {
        Color(red: 0.35, green: 0.68, blue: 0.98)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

            ScrollView {
                if layout == .grid {
                    gridContent
                } else {
                    listContent
                }
            }
        }
        .frame(minWidth: 520, minHeight: 420)
        .background(appCanvas)
    }

    private var header: some View {
        HStack(spacing: 10) {
            if dirStack.count > 1 {
                Button {
                    dirStack.removeLast()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(appIcon)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
            }

            Text(titleName)
                .font(.headline.weight(.semibold))
                .foregroundStyle(appLabel)
                .lineLimit(1)

            Spacer(minLength: 0)

            Button {
                onOpen(currentPath)
                dismiss()
            } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(appIcon)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .help("Use this folder")

            Button {
                layout = layout == .grid ? .list : .grid
            } label: {
                Image(systemName: layout == .grid ? "square.grid.2x2" : "list.bullet")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(appIcon)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(appIcon)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
        }
    }

    private var gridContent: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 20) {
            ForEach(items) { entry in
                Button {
                    tap(entry)
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: entry.isFolder ? "folder.fill" : "doc")
                            .font(.system(size: 44, weight: .regular))
                            .foregroundStyle(entry.isFolder ? folderBlue : appIcon)
                            .frame(width: 56, height: 48)
                        Text(entry.name)
                            .font(.caption)
                            .foregroundStyle(appLabel)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.vertical, 4)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }

    private var listContent: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, entry in
                Button {
                    tap(entry)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: entry.isFolder ? "folder.fill" : "doc")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundStyle(entry.isFolder ? folderBlue : appIcon)
                            .frame(width: 24)

                        Text(entry.name)
                            .font(.subheadline)
                            .foregroundStyle(appLabel)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if entry.isFolder {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)

                if index < items.count - 1 {
                    Divider()
                        .opacity(0.4)
                        .padding(.leading, 52)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 16)
    }

    private func tap(_ entry: MockFolderEntry) {
        if entry.isFolder {
            dirStack.append(entry.path)
        }
    }
}

private enum FolderLayout {
    case grid, list
}

struct MockFolderEntry: Identifiable {
    var id: String { path }
    let name: String
    let path: String
    let isFolder: Bool
}

enum MockFolderTree {
    static let home = "/Users/preview"

    static func entries(in dir: String) -> [MockFolderEntry] {
        tree[dir] ?? []
    }

    private static func folder(_ name: String, under dir: String) -> MockFolderEntry {
        MockFolderEntry(name: name, path: dir + "/" + name, isFolder: true)
    }

    private static func file(_ name: String, under dir: String) -> MockFolderEntry {
        MockFolderEntry(name: name, path: dir + "/" + name, isFolder: false)
    }

    private static let tree: [String: [MockFolderEntry]] = {
        let home = MockFolderTree.home
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
                folder("circuit", under: projects),
                folder("haven", under: projects),
            ],
            appul: [
                file("README.md", under: appul),
                file("Package.swift", under: appul),
            ],
            website: [
                file("index.html", under: website),
                file("styles.css", under: website),
            ],
            downloads: [
                file("setup.dmg", under: downloads),
                file("archive.zip", under: downloads),
            ],
            pictures: [
                file("vacation.jpg", under: pictures),
            ],
        ]
    }()
}
