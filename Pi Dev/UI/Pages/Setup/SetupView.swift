//
//  SetupView.swift
//  Pi Dev
//

import SwiftUI

struct SetupView: View {
  @AppStorage("piServerBaseURL") private var serverURL = ""
  @AppStorage("piAuthToken") private var authToken = ""

  @State private var urlDraft = ""
  @State private var tokenDraft = ""
  @State private var isChecking = false
  @State private var errorMessage: String?
  @State private var showHelp = false
  @FocusState private var focusedField: Field?

  private enum Field: Hashable {
    case url, token
  }

  private var normalizedURL: String {
    let trimmed = urlDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return "" }
    if trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://") {
      return trimmed
    }
    return "https://\(trimmed)"
  }

  private var canContinue: Bool {
    !isChecking
      && URL(string: normalizedURL) != nil
      && !tokenDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var body: some View {
    ZStack {
      Background()

      ScrollView(showsIndicators: false) {
        VStack(spacing: 28) {
        Spacer()

        VStack(spacing: 12) {
          Text("π")
            .font(.system(size: 56, weight: .light, design: .serif))
            .foregroundStyle(appGradient)

          Text("Welcome to Pi Dev")
            .font(.title.weight(.semibold))

          Text("Connect to your Pi server to get started.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }

        VStack(spacing: 16) {
          inputField(
            icon: "link",
            prompt: "Server URL",
            text: $urlDraft,
            field: .url
          ) {
            TextField("Server URL", text: $urlDraft)
              .textInputAutocapitalization(.never)
              .autocorrectionDisabled()
              .keyboardType(.URL)
          }

          inputField(
            icon: "key.fill",
            prompt: "Authentication token",
            text: $tokenDraft,
            field: .token
          ) {
            SecureField("Authentication token", text: $tokenDraft, prompt: Text("Enter token"))
              .textInputAutocapitalization(.never)
              .autocorrectionDisabled()
          }
        }
        .padding(.horizontal, 32)

        VStack(spacing: 12) {
          Button {
            continueTapped()
          } label: {
            HStack(spacing: 8) {
              if isChecking {
                ProgressView()
                  .tint(.white)
                  .scaleEffect(0.8)
              }
              Text(isChecking ? "Checking…" : "Continue")
                .font(.subheadline.weight(.semibold))
              if !isChecking {
                Image(systemName: "arrow.right")
                  .font(.system(size: 14, weight: .semibold))
              }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
              canContinue
                ? AnyShapeStyle(appGradient)
                : AnyShapeStyle(.gray.opacity(0.4)),
              in: .rect(cornerRadius: 20)
            )
          }
          .buttonStyle(.plain)
          .disabled(!canContinue)

          if let errorMessage {
            HStack(spacing: 6) {
              Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption)
              Text(errorMessage)
                .font(.caption)
            }
            .foregroundStyle(.orange)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
          }
        }
        .padding(.horizontal, 32)

        // Help: set password (pi-backend)
        VStack(spacing: 12) {
          Button {
            withAnimation(.snappy) { showHelp.toggle() }
          } label: {
            HStack(spacing: 6) {
              Image(systemName: "questionmark.circle")
                .font(.caption.weight(.semibold))
              Text("Where to get server info?")
                .font(.caption.weight(.semibold))
              Image(systemName: showHelp ? "chevron.up" : "chevron.down")
                .font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(.secondary)
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(.ultraThinMaterial, in: .capsule)
          }
          .buttonStyle(.plain)

          if showHelp {
            VStack(alignment: .leading, spacing: 12) {
              Text("Run your Pi server, then use its URL and token here.")
                .font(.caption)
                .foregroundStyle(.secondary)

              VStack(alignment: .leading, spacing: 6) {
                Label("1. Start the server with a password and port", systemImage: "key.fill")
                  .font(.caption.weight(.semibold))
                codeBlock("PI_API_TOKEN=super-secret PORT=3000 npx pi-rpc-server@latest")
                Text("Pick any strong password and free port. This starts the server on http://localhost:3000.")
                  .font(.caption2)
                  .foregroundStyle(.secondary)
              }

              VStack(alignment: .leading, spacing: 6) {
                Label("2. Tunnel that port and connect", systemImage: "link")
                  .font(.caption.weight(.semibold))
                Text("Expose your localhost with any tunnel, then paste the public URL into Server URL and the same PI_API_TOKEN into Authentication token.")
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }

              Divider().opacity(0.4)

              Link(destination: URL(string: "https://github.com/thisisommore/pi-backend#readme")!) {
                Label("github.com/thisisommore/pi-backend", systemImage: "arrow.up.right.square")
                  .font(.caption)
              }
            }
            .padding(14)
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
            .overlay(
              RoundedRectangle(cornerRadius: 16)
                .stroke(.secondary.opacity(0.2), lineWidth: 0.5)
            )
            .transition(.opacity.combined(with: .move(edge: .top)))
          }
        }
        .padding(.horizontal, 32)

          Spacer(minLength: 20)
        }
        .padding(.vertical, 40)
      }
    }
    .onAppear {
      urlDraft = serverURL
      tokenDraft = authToken
      focusedField = .url
    }
  }

  @ViewBuilder
  private func inputField<F: View>(
    icon: String,
    prompt: String,
    text: Binding<String>,
    field: Field,
    @ViewBuilder content: () -> F
  ) -> some View {
    HStack(spacing: 12) {
      Image(systemName: icon)
        .foregroundStyle(.secondary)
        .frame(width: 24)

      content()
        .font(.callout)
        .focused($focusedField, equals: field)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 14)
    .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .stroke(.secondary.opacity(0.25), lineWidth: 0.5)
    )
  }

  @ViewBuilder
  private func codeBlock(_ text: String, compact: Bool = false) -> some View {
    HStack(spacing: 8) {
      Text(text)
        .font(.system(compact ? .caption2 : .caption, design: .monospaced))
        .foregroundStyle(.primary)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .truncationMode(.middle)
      Spacer(minLength: 8)
      Button {
        #if canImport(UIKit)
          UIPasteboard.general.string = text
        #endif
      } label: {
        Image(systemName: "doc.on.doc")
          .font(.system(size: compact ? 11 : 12, weight: .medium))
          .foregroundStyle(.secondary)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Copy \(text)")
    }
    .padding(.horizontal, 10)
    .padding(.vertical, compact ? 6 : 8)
    .background(Color.primary.opacity(0.08), in: .rect(cornerRadius: 8))
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(.secondary.opacity(0.15), lineWidth: 0.5)
    )
  }

  private func continueTapped() {
    let trimmedToken = tokenDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedToken.isEmpty, let url = URL(string: normalizedURL) else { return }

    isChecking = true
    errorMessage = nil
    focusedField = nil

    Task { @MainActor in
      let client = PiRPCClient(baseURL: url, authToken: trimmedToken)
      let result = await client.healthCheck()

      isChecking = false

      switch result {
      case .success:
        withAnimation(.snappy) {
          serverURL = url.absoluteString
          authToken = trimmedToken
        }
      case .failure(let error):
        errorMessage = error.localizedDescription
      }
    }
  }
}

#Preview {
  SetupView()
    .preferredColorScheme(.dark)
}
