//
//  MockData.swift
//  Pi Dev Mac
//

import Foundation

enum MockData {
    static let sessions: [ChatSession] = [
        ChatSession(
            title: "Privacy-focused LLM chat with payment balance",
            preview: "Stick with KVAC + Bulletproofs for your system…",
            updatedAt: Date().addingTimeInterval(-60 * 12),
            messages: privacyChat,
            projectName: "circuit"
        ),
        ChatSession(
            title: "Asymmetric key signing with public key verification",
            preview: "Use Ed25519 for signing and store the public key…",
            updatedAt: Date().addingTimeInterval(-60 * 45),
            messages: signingChat,
            projectName: "circuit"
        ),
        ChatSession(
            title: "Verify attack scenario",
            preview: "The replay path fails when the nonce window rolls…",
            updatedAt: Date().addingTimeInterval(-60 * 90),
            messages: attackChat,
            projectName: "circuit"
        ),
        ChatSession(
            title: "do u find any issues in this, like pr",
            preview: "Two race conditions in the mint path — details below.",
            updatedAt: Date().addingTimeInterval(-60 * 60 * 3),
            messages: prReviewChat,
            projectName: "circuit"
        ),
        ChatSession(
            title: "Create bike engine sound",
            preview: "Generated a short WAV loop with pitch envelope…",
            updatedAt: Date().addingTimeInterval(-60 * 60 * 5),
            messages: bikeChat,
            projectName: "bike-rev-simulator"
        ),
        ChatSession(
            title: "which skills are there, can u list them",
            preview: "Here are the skills currently registered…",
            updatedAt: Date().addingTimeInterval(-60 * 60 * 8),
            messages: skillsChat,
            projectName: "om_landing"
        ),
        ChatSession(
            title: "Fix duplicate iOS sends",
            preview: "Guard the send pipeline with an in-flight token…",
            updatedAt: Date().addingTimeInterval(-60 * 60 * 22),
            messages: iosSendsChat,
            projectName: "xx-network"
        ),
        ChatSession(
            title: "Create Android mock UI pages",
            preview: "Scaffolded Compose screens for onboarding…",
            updatedAt: Date().addingTimeInterval(-60 * 60 * 30),
            messages: androidUIChat,
            projectName: "xx-network"
        ),
        ChatSession(
            title: "Find and propose code improvements",
            preview: "I scanned the networking stack and found…",
            updatedAt: Date().addingTimeInterval(-60 * 60 * 40),
            messages: improveChat,
            projectName: "haven"
        ),
        ChatSession(
            title: "Capture interval ID and clean up",
            preview: "Store the timer handle and clear it on dispose…",
            updatedAt: Date().addingTimeInterval(-60 * 60 * 50),
            messages: intervalChat,
            projectName: "haven"
        ),
        ChatSession(
            title: "Find and fix a bug in code",
            preview: "The off-by-one was in the ring buffer write…",
            updatedAt: Date().addingTimeInterval(-60 * 60 * 55),
            messages: bugfixChat,
            projectName: "haven"
        ),
        ChatSession(
            title: "Find reason for UI thread jank",
            preview: "Main-thread JSON decode on every scroll frame…",
            updatedAt: Date().addingTimeInterval(-60 * 60 * 70),
            messages: jankChat,
            projectName: "haven"
        )
    ]

    // MARK: - Conversations

    private static let privacyChat: [ChatMessage] = [
        ChatMessage(
            role: .user,
            text: """
            Your use case:
            • Mint issues credit to user
            • Gate (your own server) verifies — shares key with Mint
            • No third-party verification needed

            KVAC is better here?
            """,
            createdAt: Date().addingTimeInterval(-60 * 20)
        ),
        ChatMessage(
            role: .assistant,
            text: """
            Stick with **KVAC + Bulletproofs** for your system. Here's why:

            1. Your Mint and Gate share a key anyway — KVAC is designed for this
            2. Amount arithmetic (deduction) is native in KVAC via Pedersen
            3. Faster — no pairing operations (BBS+ needs BLS12-381 pairings)
            4. Less complexity — BBS+ + amount hiding = KVAC anyway
            5. cashu-kvac library is battle-tested in production (Cashu mint)

            BBS+ would become the better choice if you ever add a **third party verifier** — for example, if you want other LLM providers to accept your credentials without sharing your secret key. That's a meaningful architectural change worth keeping in mind for the future, but for the system you've designed, KVAC is the right tool.
            """,
            codeBlocks: [
                CodeBlock(
                    language: "swift",
                    source: """
                    struct CredentialBalance {
                        let commitment: PedersenCommitment
                        let proof: Bulletproof

                        func deduct(_ amount: UInt64, with key: SharedKey) throws -> Self {
                            let next = try commitment.subtract(amount, using: key)
                            let range = try Bulletproof.prove(next, upperBound: .maxBalance)
                            return CredentialBalance(commitment: next, proof: range)
                        }
                    }
                    """
                )
            ],
            createdAt: Date().addingTimeInterval(-60 * 12)
        )
    ]

    private static let signingChat: [ChatMessage] = [
        ChatMessage(
            role: .user,
            text: "Should we use RSA or Ed25519 for asymmetric signing of session tokens?",
            createdAt: Date().addingTimeInterval(-60 * 50)
        ),
        ChatMessage(
            role: .assistant,
            text: """
            Prefer **Ed25519** for session token signatures.

            • Smaller keys and signatures (32 / 64 bytes)
            • Constant-time verification — fewer timing pitfalls
            • First-class support via CryptoKit on Apple platforms
            • RSA only wins if you must interop with a legacy verifier

            Store the public key in the Gate config; never ship the private key to clients.
            """,
            codeBlocks: [
                CodeBlock(
                    language: "swift",
                    source: """
                    import CryptoKit

                    let privateKey = Curve25519.Signing.PrivateKey()
                    let signature = try privateKey.signature(for: tokenData)
                    let isValid = privateKey.publicKey.isValidSignature(signature, for: tokenData)
                    """
                )
            ],
            createdAt: Date().addingTimeInterval(-60 * 45)
        )
    ]

    private static let attackChat: [ChatMessage] = [
        ChatMessage(
            role: .user,
            text: "Verify this attack scenario: an attacker replays a spent token within the same 30s nonce window.",
            createdAt: Date().addingTimeInterval(-60 * 100)
        ),
        ChatMessage(
            role: .assistant,
            text: """
            Replays inside the nonce window are already blocked if you keep a spent-token set keyed by `(nullifier, window)`.

            Gaps I found:
            • The set is process-local — multi-instance Gate needs Redis or similar
            • Window rollover drops old entries; an attacker can race the boundary
            • Missing HMAC on the window id lets a client claim an adjacent window

            Fix: shared spent store + inclusive window edges + bind window id into the signature payload.
            """,
            createdAt: Date().addingTimeInterval(-60 * 90)
        )
    ]

    private static let prReviewChat: [ChatMessage] = [
        ChatMessage(
            role: .user,
            text: "do u find any issues in this, like pr",
            createdAt: Date().addingTimeInterval(-60 * 60 * 3 - 120)
        ),
        ChatMessage(
            role: .assistant,
            text: """
            Two race conditions in the mint path:

            1. **Double spend on concurrent redeem** — `balance` is read, then written without a lock. Two requests can both pass the check.
            2. **Partial write on crash** — ledger append happens after credit; a crash leaves ghost credit.

            Suggested PR notes: wrap redeem in a DB transaction with `SELECT … FOR UPDATE`, and write the ledger row first (or use an outbox). Happy to draft the patch.
            """,
            createdAt: Date().addingTimeInterval(-60 * 60 * 3)
        )
    ]

    private static let bikeChat: [ChatMessage] = [
        ChatMessage(
            role: .user,
            text: "Create bike engine sound that revs with throttle input",
            createdAt: Date().addingTimeInterval(-60 * 60 * 5 - 60)
        ),
        ChatMessage(
            role: .assistant,
            text: "Generated a short WAV loop with a pitch envelope driven by throttle 0…1. Drop it in `Resources/Audio/engine_loop.wav` and map throttle to `AVAudioUnitTimePitch.rate`.",
            createdAt: Date().addingTimeInterval(-60 * 60 * 5)
        )
    ]

    private static let skillsChat: [ChatMessage] = [
        ChatMessage(
            role: .user,
            text: "which skills are there, can u list them",
            createdAt: Date().addingTimeInterval(-60 * 60 * 8 - 40)
        ),
        ChatMessage(
            role: .assistant,
            text: """
            Skills currently registered:

            • **swift-ui** — layout, navigation, glass materials
            • **code-review** — PR comments and risk flags
            • **crypto-primitives** — KVAC, BBS+, Bulletproofs notes
            • **test-gen** — XCTest / Swift Testing scaffolds
            • **repo-search** — semantic + regex over the workspace
            """,
            createdAt: Date().addingTimeInterval(-60 * 60 * 8)
        )
    ]

    private static let iosSendsChat: [ChatMessage] = [
        ChatMessage(
            role: .user,
            text: "Fix duplicate iOS sends when user double-taps Send",
            createdAt: Date().addingTimeInterval(-60 * 60 * 22 - 80)
        ),
        ChatMessage(
            role: .assistant,
            text: "Guard the send pipeline with an in-flight token. Disable the button while `isSending`, and ignore second taps until the task finishes or fails.",
            codeBlocks: [
                CodeBlock(
                    language: "swift",
                    source: """
                    @MainActor
                    func send() async {
                        guard !isSending else { return }
                        isSending = true
                        defer { isSending = false }
                        try? await client.send(draft)
                    }
                    """
                )
            ],
            createdAt: Date().addingTimeInterval(-60 * 60 * 22)
        )
    ]

    private static let androidUIChat: [ChatMessage] = [
        ChatMessage(
            role: .user,
            text: "Create Android mock UI pages for onboarding",
            createdAt: Date().addingTimeInterval(-60 * 60 * 30 - 50)
        ),
        ChatMessage(
            role: .assistant,
            text: "Scaffolded Compose screens: Welcome, Permissions, and WalletSetup. Each uses a shared `OnboardingScaffold` with progress dots and a primary CTA.",
            createdAt: Date().addingTimeInterval(-60 * 60 * 30)
        )
    ]

    private static let improveChat: [ChatMessage] = [
        ChatMessage(
            role: .user,
            text: "Find and propose code improvements in the networking stack",
            createdAt: Date().addingTimeInterval(-60 * 60 * 40 - 90)
        ),
        ChatMessage(
            role: .assistant,
            text: "I scanned the networking stack and found three high-ROI changes: unify retry policy, cancel in-flight requests on logout, and move JSON decode off the main actor.",
            createdAt: Date().addingTimeInterval(-60 * 60 * 40)
        )
    ]

    private static let intervalChat: [ChatMessage] = [
        ChatMessage(
            role: .user,
            text: "Capture interval ID and clean up on view dispose",
            createdAt: Date().addingTimeInterval(-60 * 60 * 50 - 30)
        ),
        ChatMessage(
            role: .assistant,
            text: "Store the timer handle and clear it on dispose. In SwiftUI prefer `.task` cancellation over raw `Timer` when you can.",
            createdAt: Date().addingTimeInterval(-60 * 60 * 50)
        )
    ]

    private static let bugfixChat: [ChatMessage] = [
        ChatMessage(
            role: .user,
            text: "Find and fix a bug in the ring buffer",
            createdAt: Date().addingTimeInterval(-60 * 60 * 55 - 40)
        ),
        ChatMessage(
            role: .assistant,
            text: "The off-by-one was in the ring buffer write index when capacity was a power of two. Mask with `capacity - 1` after increment, not before.",
            createdAt: Date().addingTimeInterval(-60 * 60 * 55)
        )
    ]

    private static let jankChat: [ChatMessage] = [
        ChatMessage(
            role: .user,
            text: "Find reason for UI thread jank while scrolling the chat list",
            createdAt: Date().addingTimeInterval(-60 * 60 * 70 - 60)
        ),
        ChatMessage(
            role: .assistant,
            text: "Main-thread JSON decode on every scroll frame was the culprit — pre-decode message bodies when they arrive and only bind lightweight view models in the list.",
            createdAt: Date().addingTimeInterval(-60 * 60 * 70)
        )
    ]
}
