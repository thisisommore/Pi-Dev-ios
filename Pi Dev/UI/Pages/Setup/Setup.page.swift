//
//  Setup.page.swift
//  Pi Dev
//

import SwiftUI
import Combine

struct SetupPage: View {
  @State private var controller = SetupPageController()

  @FocusState private var focusedField: SetupPageController.Field?

  var body: some View {
    ZStack {
      Background()

      ScrollView(showsIndicators: false) {
        VStack(spacing: 28) {
          Spacer()

          VStack(spacing: 12) {
            Text("π")
              .font(.system(size: 56, weight: .light, design: .serif))
              .foregroundStyle(appColor)

            Text("Welcome to Pi Dev")
              .font(.title.weight(.semibold))

            Text("Connect to your Pi server to get started.")
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .multilineTextAlignment(.center)
          }

          VStack(spacing: 16) {
            self.inputField(
              icon: "link",
              prompt: "Server URL",
              field: .url
            ) {
              TextField("Server URL", text: self.$controller.urlDraft)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
            }

            self.inputField(
              icon: "key.fill",
              prompt: "Authentication token",
              field: .token
            ) {
              SecureField(
                "Authentication token",
                text: self.$controller.tokenDraft,
                prompt: Text("Enter token")
              )
              .textInputAutocapitalization(.never)
              .autocorrectionDisabled()
            }
          }
          .padding(.horizontal, 32)

          VStack(spacing: 12) {
            Button {
              self.controller.continueTapped()
            } label: {
              HStack(spacing: 8) {
                if self.controller.isChecking {
                  ProgressView()
                    .tint(appOnInk)
                    .scaleEffect(0.8)
                }
                Text(self.controller.isChecking ? "Checking…" : "Continue")
                  .font(.subheadline.weight(.semibold))
                if !self.controller.isChecking {
                  Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .semibold))
                }
              }
              .foregroundStyle(
                self.controller.canContinue
                  ? AnyShapeStyle(appOnInk)
                  : AnyShapeStyle(.secondary)
              )
              .frame(maxWidth: .infinity)
              .padding(.vertical, 16)
              .background(
                self.controller.canContinue
                  ? AnyShapeStyle(appColor)
                  : AnyShapeStyle(Color.primary.opacity(0.12)),
                in: .rect(cornerRadius: 20)
              )
            }
            .buttonStyle(.plain)
            .disabled(!self.controller.canContinue)

            if let errorMessage = self.controller.errorMessage {
              HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                  .font(.caption)
                Text(errorMessage)
                  .font(.caption)
              }
              .foregroundStyle(.secondary)
              .multilineTextAlignment(.center)
              .padding(.horizontal, 8)
            }
          }
          .padding(.horizontal, 32)

          VStack(spacing: 12) {
            Button {
              withAnimation(.snappy) { self.controller.showHelp.toggle() }
            } label: {
              HStack(spacing: 6) {
                Image(systemName: "questionmark.circle")
                  .font(.caption.weight(.semibold))
                Text("Where to get server info?")
                  .font(.caption.weight(.semibold))
                Image(systemName: self.controller.showHelp ? "chevron.up" : "chevron.down")
                  .font(.system(size: 10, weight: .bold))
              }
              .foregroundStyle(.secondary)
              .padding(.vertical, 6)
              .padding(.horizontal, 12)
              .background(.ultraThinMaterial, in: .capsule)
            }
            .buttonStyle(.plain)

            if self.controller.showHelp {
              self.helpPanel
            }
          }
          .padding(.horizontal, 32)

          Spacer(minLength: 20)
        }
        .padding(.vertical, 40)
      }
    }
    .onAppear {
      self.controller.hydrateFromStorage()
      self.focusedField = .url
    }
  }

  private var helpPanel: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Run your Pi server, then use its URL and token here.")
        .font(.caption)
        .foregroundStyle(.secondary)

      VStack(alignment: .leading, spacing: 6) {
        Label("1. Start the server with a password and port", systemImage: "key.fill")
          .font(.caption.weight(.semibold))
        self.codeBlock("PI_API_TOKEN=super-secret PORT=3000 npx pi-rpc-server@latest")
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

  @ViewBuilder
  private func inputField<F: View>(
    icon: String,
    prompt: String,
    field: SetupPageController.Field,
    @ViewBuilder content: () -> F
  ) -> some View {
    HStack(spacing: 12) {
      Image(systemName: icon)
        .foregroundStyle(.secondary)
        .frame(width: 24)

      content()
        .font(.callout)
        .focused(self.$focusedField, equals: field)
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
        .foregroundStyle(appLabel)
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
}

#Preview {
  Mock {
    SetupPage()
  }
  .preferredColorScheme(.dark)
}
