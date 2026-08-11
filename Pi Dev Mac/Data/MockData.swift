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
            projectName: "circuit",
            fileChanges: privacyChanges
        ),
        ChatSession(
            title: "Asymmetric key signing with public key verification",
            preview: "Use Ed25519 for signing and store the public key…",
            updatedAt: Date().addingTimeInterval(-60 * 45),
            messages: signingChat,
            projectName: "circuit",
            fileChanges: signingChanges
        ),
        ChatSession(
            title: "Verify attack scenario",
            preview: "The replay path fails when the nonce window rolls…",
            updatedAt: Date().addingTimeInterval(-60 * 90),
            messages: attackChat,
            projectName: "circuit",
            fileChanges: attackChanges
        ),
        ChatSession(
            title: "do u find any issues in this, like pr",
            preview: "Two race conditions in the mint path — details below.",
            updatedAt: Date().addingTimeInterval(-60 * 60 * 3),
            messages: prReviewChat,
            projectName: "circuit",
            fileChanges: prReviewChanges
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
            projectName: "xx-network",
            fileChanges: iosSendsChanges
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
            projectName: "haven",
            fileChanges: improveChanges
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
            projectName: "haven",
            fileChanges: bugfixChanges
        ),
        ChatSession(
            title: "Find reason for UI thread jank",
            preview: "Main-thread JSON decode on every scroll frame…",
            updatedAt: Date().addingTimeInterval(-60 * 60 * 70),
            messages: jankChat,
            projectName: "haven",
            fileChanges: jankChanges
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

    private static let privacyChanges: [FileChange] = [
        FileChange(
            path: "Sources/Crypto/KVAC/CredentialBalance.swift",
            additions: 31,
            deletions: 12,
            diff: """
            @@ -10,12 +10,31 @@ struct CredentialBalance {
                 let commitment: PedersenCommitment
                 let proof: Bulletproof
            +    let key: SharedKey
            +
            +    init(
            +        commitment: PedersenCommitment,
            +        proof: Bulletproof,
            +        key: SharedKey
            +    ) {
            +        self.commitment = commitment
            +        self.proof = proof
            +        self.key = key
            +    }
            
                 func deduct(_ amount: UInt64, with key: SharedKey) throws -> Self {
            -        let next = try commitment.subtract(amount, using: key)
            +        let next = try commitment.subtract(amount, using: self.key)
                     let range = try Bulletproof.prove(next, upperBound: .maxBalance)
            -        return CredentialBalance(commitment: next, proof: range)
            +        return CredentialBalance(commitment: next, proof: range, key: key)
                 }
             }
            """
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

    private static let signingChanges: [FileChange] = [
        FileChange(
            path: "Sources/Auth/TokenSigner.swift",
            additions: 14,
            deletions: 6,
            diff: """
            @@ -1,8 +1,14 @@
             import CryptoKit
            
             enum TokenSigner {
            -    static func sign(_ data: Data, rsaKey: SecKey) throws -> Data {
            -        // legacy RSA path
            +    static func sign(_ data: Data) throws -> Data {
            +        let privateKey = Curve25519.Signing.PrivateKey()
            +        return try privateKey.signature(for: data)
            +    }
            +
            +    static func verify(_ data: Data, signature: Data, publicKey: Data) throws -> Bool {
            +        let key = try Curve25519.Signing.PublicKey(rawRepresentation: publicKey)
            +        return key.isValidSignature(signature, for: data)
                 }
             }
            """
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

    private static let attackChanges: [FileChange] = [
        FileChange(
            path: "Sources/Gate/NonceValidator.swift",
            additions: 27,
            deletions: 9,
            diff: """
            @@ -22,9 +22,27 @@ actor NonceValidator {
                 func validate(_ nullifier: Nullifier, window: UInt64) async throws {
                     let key = SpentKey(nullifier: nullifier, window: window)
            -        guard await spentSet.insert(key).inserted else {
            -            throw ValidationError.replay
            +        guard await spentStore.insert(key).inserted else {
            +            throw ValidationError.replay
                     }
            +        let hmac = HMAC<SHA256>.authenticationCode(for: window.bigEndian.data, using: windowKey)
            +        guard proof.windowHMAC == Data(hmac) else {
            +            throw ValidationError.invalidWindow
            +        }
                 }
            """
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

    private static let prReviewChanges: [FileChange] = [
        FileChange(
            path: "Sources/Mint/RedeemService.swift",
            additions: 23,
            deletions: 8,
            diff: """
            @@ -45,7 +45,9 @@ final class RedeemService {
                 func redeem(_ proof: RedeemProof) async throws -> RedeemReceipt {
            -        let balance = try await ledger.balance(for: proof.key)
            -        guard balance >= proof.amount else { throw .insufficientFunds }
            +        try await ledger.transaction { tx in
            +            let balance = try await tx.balance(for: proof.key)
            +            guard balance >= proof.amount else { throw .insufficientFunds }
            +            try await tx.debit(proof.key, amount: proof.amount)
            +        }
                     let receipt = RedeemReceipt(proof: proof)
            -        try await ledger.debit(proof.key, amount: proof.amount)
                     try await ledger.append(receipt)
            """
        ),
        FileChange(
            path: "Tests/Mint/RedeemServiceTests.swift",
            additions: 47,
            deletions: 3,
            diff: """
            @@ -12,6 +12,50 @@ final class RedeemServiceTests: XCTestCase {
                     let service = RedeemService(ledger: ledger)
                     _ = try await service.redeem(proof)
                     XCTAssertEqual(ledger.entries.count, 1)
            +    }
            +
            +    func testConcurrentRedeemPreventsDoubleSpend() async throws {
            +        let ledger = InMemoryLedger(initialBalance: 100)
            +        let service = RedeemService(ledger: ledger)
            +        let proof = RedeemProof(amount: 100)
            +        await withTaskGroup(of: Void.self) { group in
            +            for _ in 0..<10 {
            +                group.addTask {
            +                    try? await service.redeem(proof)
            +                }
            +            }
            +        }
            +        XCTAssertEqual(ledger.totalDebited, 100)
                 }
            """
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

    private static let iosSendsChanges: [FileChange] = [
        FileChange(
            path: "Sources/iOS/ChatViewModel.swift",
            additions: 19,
            deletions: 4,
            diff: """
            @@ -32,8 +32,23 @@ final class ChatViewModel: ObservableObject {
                 @Published var draft: String = ""
            -    @Published var isSending: Bool = false
            +    private var sendTask: Task<Void, Never>?
            
                 func send() async {
            -        isSending = true
            -        defer { isSending = false }
            -        try? await client.send(draft)
            +        guard sendTask == nil else { return }
            +        sendTask = Task {
            +            defer { sendTask = nil }
            +            do {
            +                try await client.send(draft)
            +            } catch {
            +                handle(error)
            +            }
            +        }
                 }
            """
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

    private static let improveChanges: [FileChange] = [
        FileChange(
            path: "Sources/Network/RequestCoordinator.swift",
            additions: 18,
            deletions: 42,
            diff: """
            @@ -88,20 +88,12 @@ actor RequestCoordinator {
                 func perform<T: Decodable>(_ request: Request<T>) async throws -> T {
            -        return try await withRetry(policy: .default) {
            -            let (data, response) = try await urlSession.data(for: request.urlRequest)
            -            try Task.checkCancellation()
            -            return try JSONDecoder().decode(T.self, from: data)
            -        }
            +        let (data, _) = try await urlSession.data(for: request.urlRequest)
            +        return try await Task.detached(priority: .userInitiated) {
            +            try JSONDecoder().decode(T.self, from: data)
            +        }.value
                 }
            """
        ),
        FileChange(
            path: "Sources/Network/RetryPolicy.swift",
            additions: 56,
            deletions: 0,
            diff: """
            @@ -0,0 +1,56 @@
            +import Foundation
            +
            +struct RetryPolicy {
            +    let maxAttempts: Int
            +    let baseDelay: Duration
            +    let maxDelay: Duration
            +
            +    static let `default` = RetryPolicy(maxAttempts: 3, baseDelay: .milliseconds(200), maxDelay: .seconds(5))
            +
            +    func delay(forAttempt attempt: Int) -> Duration {
            +        let exponential = baseDelay * Int(pow(2.0, Double(attempt)))
            +        return min(exponential, maxDelay)
            +    }
            +}
            """
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

    private static let bugfixChanges: [FileChange] = [
        FileChange(
            path: "Sources/Utils/RingBuffer.swift",
            additions: 7,
            deletions: 3,
            diff: """
            @@ -18,9 +18,13 @@ struct RingBuffer<Element> {
                 mutating func append(_ element: Element) {
            -        writeIndex &= capacity - 1
                     buffer[writeIndex] = element
            -        writeIndex += 1
            +        writeIndex += 1
            +        writeIndex &= capacity - 1
                     count = min(count + 1, capacity)
                 }
            """
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

    private static let jankChanges: [FileChange] = [
        FileChange(
            path: "Sources/UI/MessageListViewModel.swift",
            additions: 34,
            deletions: 12,
            diff: """
            @@ -40,18 +40,30 @@ final class MessageListViewModel: ObservableObject {
                 func loadMessages() async {
            -        let decoded = messages.map { try! JSONDecoder().decode(MessageViewModel.self, from: $0.body) }
            -        await MainActor.run {
            -            self.viewModels = decoded
            -        }
            +        let viewModels = await Task.detached(priority: .userInitiated) {
            +            messages.map { message in
            +                MessageViewModel(
            +                    id: message.id,
            +                    renderedBody: render(message.body)
            +                )
            +            }
            +        }.value
            +        self.viewModels = viewModels
                 }
            """
        )
    ]
}
