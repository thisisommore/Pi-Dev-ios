//
//  RepoPickerSheet.swift
//  Pi Dev
//

import SwiftUI
import UIKit

struct RepoPickerSheet: View {
  @Bindable var store: ChatStore
  @Environment(\.dismiss) private var dismiss
  @State private var pastedURL = ""
  @State private var githubUsername = ""
  @State private var githubRepos: [GitHubRepo] = []
  @State private var isLoading = false
  @State private var errorMessage: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Capsule()
        .fill(.tertiary)
        .frame(width: 36, height: 5)
        .frame(maxWidth: .infinity)
        .padding(.top, 10)

      Text("Include Git Repository")
        .font(.headline)
        .padding(.horizontal, 16)
        .padding(.top, 16)

      if let selected = store.includedRepo {
        HStack(spacing: 10) {
          Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(appColor)
          VStack(alignment: .leading, spacing: 2) {
            Text(selected.name)
              .font(.subheadline.weight(.semibold))
              .lineLimit(1)
            Text(selected.url)
              .font(.caption2)
              .foregroundStyle(.secondary)
              .lineLimit(1)
          }
          Spacer()
          Button {
            store.clearRepo()
          } label: {
            Image(systemName: "xmark")
              .font(.system(size: 12, weight: .bold))
              .foregroundStyle(.secondary)
              .frame(width: 24, height: 24)
              .background(.secondary.opacity(0.15), in: .circle)
          }
          .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.secondary.opacity(0.12), in: .rect(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.top, 12)
      }

      Form {
        Section("Paste repo URL or path") {
          HStack(spacing: 10) {
            TextField("Repo URL or path", text: $pastedURL)
              .textInputAutocapitalization(.never)
              .autocorrectionDisabled()

            Button {
              if let text = UIPasteboard.general.string {
                pastedURL = text
              }
            } label: {
              Image(systemName: "doc.on.clipboard")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
          }

          Button {
            includePastedRepo()
          } label: {
            HStack {
              Spacer()
              Text("Include")
              Spacer()
            }
          }
          .disabled(pastedURL.trimmingCharacters(in: .whitespaces).isEmpty)
        }

        Section("GitHub public repos") {
          HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
              .font(.system(size: 14, weight: .medium))
              .foregroundStyle(.secondary)

            TextField("GitHub username", text: $githubUsername)
              .textInputAutocapitalization(.never)
              .autocorrectionDisabled()
              .onSubmit { fetchGitHubRepos() }

            if !githubUsername.isEmpty {
              Button {
                githubUsername = ""
                githubRepos = []
              } label: {
                Image(systemName: "xmark.circle.fill")
                  .font(.system(size: 18))
                  .foregroundStyle(.secondary)
              }
              .buttonStyle(.plain)
            }
          }

          Button {
            fetchGitHubRepos()
          } label: {
            HStack {
              Spacer()
              if isLoading {
                ProgressView()
                  .scaleEffect(0.8)
              } else {
                Text("Search")
              }
              Spacer()
            }
          }
          .disabled(githubUsername.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)

          if let errorMessage {
            Text(errorMessage)
              .font(.caption)
              .foregroundStyle(.red)
          }

          ForEach(githubRepos) { repo in
            Button {
              selectGitHubRepo(repo)
            } label: {
              HStack {
                VStack(alignment: .leading, spacing: 2) {
                  Text(repo.fullName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                  if let description = repo.description, !description.isEmpty {
                    Text(description)
                      .font(.caption2)
                      .foregroundStyle(.secondary)
                      .lineLimit(1)
                  }
                }
                Spacer()
                if store.includedRepo?.url == repo.cloneURL {
                  Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(appColor)
                }
              }
              .contentShape(.rect)
            }
            .buttonStyle(.plain)
          }
        }
      }
      .formStyle(.grouped)
      .scrollContentBackground(.hidden)
    }
  }

  private func includePastedRepo() {
    let url = pastedURL.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !url.isEmpty else { return }

    let name = URL(string: url)?.lastPathComponent.replacingOccurrences(of: ".git", with: "") ?? url
    store.selectRepo(IncludedRepo(url: url, name: name))
    dismiss()
  }

  private func fetchGitHubRepos() {
    let username = githubUsername.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !username.isEmpty else { return }

    isLoading = true
    errorMessage = nil
    githubRepos = []

    Task {
      do {
        let url = URL(string: "https://api.github.com/users/\(username)/repos?type=public&sort=updated")!
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
          throw URLError(.badServerResponse)
        }

        let repos = try JSONDecoder().decode([GitHubRepo].self, from: data)
        await MainActor.run {
          self.githubRepos = repos.sorted { $0.fullName < $1.fullName }
          self.isLoading = false
        }
      } catch {
        await MainActor.run {
          self.errorMessage = "Could not load repos."
          self.isLoading = false
        }
      }
    }
  }

  private func selectGitHubRepo(_ repo: GitHubRepo) {
    store.selectRepo(IncludedRepo(url: repo.cloneURL, name: repo.fullName))
    dismiss()
  }
}

struct GitHubRepo: Identifiable, Decodable, Sendable {
  let id: Int
  let fullName: String
  let cloneURL: String
  let description: String?

  enum CodingKeys: String, CodingKey {
    case id
    case fullName = "full_name"
    case cloneURL = "clone_url"
    case description
  }
}
