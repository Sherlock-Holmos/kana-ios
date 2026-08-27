import Foundation

// MARK: - Sync Models

struct SyncUser: Codable, Hashable {
    let id: String
    let email: String
}

struct SyncEnvelope: Codable {
    var meta: [String: AnyCodable]?
    var srsCards: [String: SRSCard]?
    var abilities: [String: Ability]?
    var activityByDay: [String: Int]?
    var dailyGoal: Int?
    var bktMasteries: [String: BKTMastery]?
    var updatedAt: Date
}

// MARK: - Keychain keys

private enum Key {
    static let accessToken = "sync.accessToken"
    static let refreshToken = "sync.refreshToken"
    static let userId = "sync.userId"
    static let userEmail = "sync.userEmail"
}

// MARK: - SyncService

/// SyncService — pulls/pushes the user's learning state to Supabase.
/// Fully local-first: when not signed in, push/pull are no-ops.
@MainActor
final class SyncService: ObservableObject {
    static let shared = SyncService()

    @Published private(set) var lastSyncedAt: Date?
    @Published private(set) var lastError: String?
    @Published private(set) var isSyncing: Bool = false
    @Published private(set) var currentUser: SyncUser?

    let settings: SyncSettings

    init(settings: SyncSettings = SyncSettings()) {
        self.settings = settings
        // Restore session from Keychain on launch so the user stays signed in.
        if let token = Keychain.get(Key.accessToken),
           let userId = Keychain.get(Key.userId),
           let email = Keychain.get(Key.userEmail),
           !token.isEmpty, !userId.isEmpty {
            self.currentUser = SyncUser(id: userId, email: email)
        }
    }

    var isReady: Bool { settings.isConfigured && currentUser != nil }

    // MARK: - Auth

    func signIn(email: String, password: String) async {
        guard settings.isConfigured else {
            lastError = "未配置 Supabase URL 或 anon key"
            return
        }
        do {
            let client = try SupabaseClient(url: settings.supabaseURL, anonKey: settings.anonKey)
            let session = try await client.signIn(email: email, password: password)
            persist(session: session)
            currentUser = session.user
            settings.userEmail = session.user.email
            lastError = nil
        } catch {
            lastError = "登录失败：\(error.localizedDescription)"
        }
    }

    func signUp(email: String, password: String) async {
        guard settings.isConfigured else {
            lastError = "未配置 Supabase URL 或 anon key"
            return
        }
        do {
            let client = try SupabaseClient(url: settings.supabaseURL, anonKey: settings.anonKey)
            let session = try await client.signUp(email: email, password: password)
            persist(session: session)
            currentUser = session.user
            settings.userEmail = session.user.email
            lastError = nil
        } catch {
            lastError = "注册失败：\(error.localizedDescription)"
        }
    }

    func signOut() {
        Keychain.delete(Key.accessToken)
        Keychain.delete(Key.refreshToken)
        Keychain.delete(Key.userId)
        Keychain.delete(Key.userEmail)
        currentUser = nil
        settings.userEmail = ""
    }

    private func persist(session: SupabaseClient.AuthSession) {
        Keychain.set(session.accessToken, forKey: Key.accessToken)
        if let refresh = session.refreshToken {
            Keychain.set(refresh, forKey: Key.refreshToken)
        }
        Keychain.set(session.user.id, forKey: Key.userId)
        Keychain.set(session.user.email, forKey: Key.userEmail)
    }

    // MARK: - Sync

    /// Push local state to server.
    func push(envelope: SyncEnvelope) async {
        guard isReady, let user = currentUser,
              let token = Keychain.get(Key.accessToken), !token.isEmpty else { return }
        isSyncing = true
        defer { isSyncing = false }
        do {
            let client = try SupabaseClient(url: settings.supabaseURL, anonKey: settings.anonKey, token: token)
            try await client.upsertUserMeta(userId: user.id, schema: settings.schemaVersion, envelope: envelope)
            lastSyncedAt = Date()
            lastError = nil
        } catch {
            lastError = "上传失败：\(error.localizedDescription)"
        }
    }

    /// Pull server state into a fresh envelope (or nil if not present).
    func pull(user: SyncUser) async -> SyncEnvelope? {
        guard settings.isConfigured,
              let token = Keychain.get(Key.accessToken), !token.isEmpty else { return nil }
        isSyncing = true
        defer { isSyncing = false }
        do {
            let client = try SupabaseClient(url: settings.supabaseURL, anonKey: settings.anonKey, token: token)
            let envelope = try await client.fetchUserMeta(userId: user.id, schema: settings.schemaVersion)
            lastSyncedAt = Date()
            lastError = nil
            return envelope
        } catch {
            lastError = "拉取失败：\(error.localizedDescription)"
            return nil
        }
    }
}

// MARK: - AnyCodable (minimal)

struct AnyCodable: Codable, Hashable {
    let value: Any

    init(_ value: Any) { self.value = value }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let v = try? c.decode(Bool.self) { value = v; return }
        if let v = try? c.decode(Int.self) { value = v; return }
        if let v = try? c.decode(Double.self) { value = v; return }
        if let v = try? c.decode(String.self) { value = v; return }
        if let v = try? c.decode([AnyCodable].self) { value = v.map(\.value); return }
        if let v = try? c.decode([String: AnyCodable].self) {
            value = v.mapValues(\.value); return
        }
        value = NSNull()
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch value {
        case let v as Bool: try c.encode(v)
        case let v as Int: try c.encode(v)
        case let v as Double: try c.encode(v)
        case let v as String: try c.encode(v)
        case let v as [Any]: try c.encode(v.map(AnyCodable.init))
        case let v as [String: Any]: try c.encode(v.mapValues(AnyCodable.init))
        default: try c.encodeNil()
        }
    }

    static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        String(describing: lhs.value) == String(describing: rhs.value)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(String(describing: value))
    }
}
