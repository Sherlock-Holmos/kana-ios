import Foundation

/// SyncTransport — pure network layer for sync envelopes.
/// Stateless: each call takes the credentials it needs, returns data or throws.
/// Holds no UI state, no Combine subscriptions, no Keychain reads.
struct SyncTransport {

    enum TransportError: Error, LocalizedError {
        case notSignedIn
        case noToken

        var errorDescription: String? {
            switch self {
            case .notSignedIn: return "未登录"
            case .noToken:     return "缺少访问令牌"
            }
        }
    }

    let url: String
    let anonKey: String

    init(url: String, anonKey: String) {
        self.url = url
        self.anonKey = anonKey
    }

    /// Push the envelope up to the server.
    func push(envelope: SyncEnvelope, user: SyncUser, token: String, schema: Int) async throws {
        let client = try SupabaseClient(url: url, anonKey: anonKey, token: token)
        try await client.upsertUserMeta(userId: user.id, schema: schema, envelope: envelope)
    }

    /// Pull the user's envelope from the server, or nil if the user has no row yet.
    func pull(user: SyncUser, token: String, schema: Int) async throws -> SyncEnvelope? {
        let client = try SupabaseClient(url: url, anonKey: anonKey, token: token)
        return try await client.fetchUserMeta(userId: user.id, schema: schema)
    }
}