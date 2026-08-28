import Foundation
import Combine

/// AuthService — owns the signed-in user identity and the JWT tokens in Keychain.
/// Knows nothing about sync envelopes, network shapes, or app stores.
@MainActor
final class AuthService: ObservableObject {

    @Published private(set) var currentUser: SyncUser?

    /// True when we have a non-empty access token in Keychain for the current user.
    var isSignedIn: Bool {
        currentUser != nil && !(accessToken?.isEmpty ?? true)
    }

    /// Keychain keys — kept here (instead of inside SyncService) so any future
    /// caller that needs tokens can ask AuthService without reaching into Keychain.
    private enum Key {
        static let accessToken = "sync.accessToken"
        static let refreshToken = "sync.refreshToken"
        static let userId = "sync.userId"
        static let userEmail = "sync.userEmail"
    }

    init() {
        // Restore session from Keychain on launch so the user stays signed in.
        if let token = Keychain.get(Key.accessToken),
           let userId = Keychain.get(Key.userId),
           let email = Keychain.get(Key.userEmail),
           !token.isEmpty, !userId.isEmpty {
            self.currentUser = SyncUser(id: userId, email: email)
        }
    }

    // MARK: - Public auth flow

    /// Sign in against a Supabase project. Persists the resulting session.
    /// Returns the session so the caller (SyncCoordinator) can immediately push/pull.
    func signIn(url: String, anonKey: String, email: String, password: String) async throws -> SupabaseClient.AuthSession {
        let client = try SupabaseClient(url: url, anonKey: anonKey)
        let session = try await client.signIn(email: email, password: password)
        persist(session: session)
        currentUser = session.user
        return session
    }

    func signUp(url: String, anonKey: String, email: String, password: String) async throws -> SupabaseClient.AuthSession {
        let client = try SupabaseClient(url: url, anonKey: anonKey)
        let session = try await client.signUp(email: email, password: password)
        persist(session: session)
        currentUser = session.user
        return session
    }

    func signOut() {
        Keychain.delete(Key.accessToken)
        Keychain.delete(Key.refreshToken)
        Keychain.delete(Key.userId)
        Keychain.delete(Key.userEmail)
        currentUser = nil
    }

    // MARK: - Token access (used by SyncCoordinator)

    /// Bearer token for the current session, or nil when signed out / stale.
    var accessToken: String? {
        guard let token = Keychain.get(Key.accessToken), !token.isEmpty else { return nil }
        return token
    }

    // MARK: - Persistence

    private func persist(session: SupabaseClient.AuthSession) {
        Keychain.set(session.accessToken, forKey: Key.accessToken)
        if let refresh = session.refreshToken {
            Keychain.set(refresh, forKey: Key.refreshToken)
        }
        Keychain.set(session.user.id, forKey: Key.userId)
        Keychain.set(session.user.email, forKey: Key.userEmail)
    }
}