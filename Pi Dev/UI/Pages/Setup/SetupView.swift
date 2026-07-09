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
    return "http://\(trimmed)"
  }

  private var canContinue: Bool {
    !isChecking
      && URL(string: normalizedURL) != nil
      && !tokenDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var body: some View {
    ZStack {
      Background()

      VStack(spacing: 28) {
        Spacer()

        VStack(spacing: 12) {
          Text("π")
            .font(.system(size: 56, weight: .thin, design: .serif))
            .foregroundStyle(appColor)

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
                ? AnyShapeStyle(appColor.gradient)
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

        Spacer()
      }
      .padding(.vertical, 40)
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
