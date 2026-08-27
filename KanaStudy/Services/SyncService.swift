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

// MARK: - SyncService

/// SyncService — pulls/pushes the user's learning state to Supabase.
/// Fully local-first: when SyncSettings.isConfigured is false, push/pull are no-ops.
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
            let user = try await client.signIn(email: email, password: password)
            currentUser = user
            settings.userEmail = user.email
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
            let user = try await client.signUp(email: email, password: password)
            currentUser = user
            settings.userEmail = user.email
            lastError = nil
        } catch {
            lastError = "注册失败：\(error.localizedDescription)"
        }
    }

    func signOut() {
        currentUser = nil
        settings.userEmail = ""
    }

    // MARK: - Sync

    /// Push local state to server.
    func push(envelope: SyncEnvelope) async {
        guard isReady, let user = currentUser else { return }
        isSyncing = true
        defer { isSyncing = false }
        do {
            let client = try SupabaseClient(url: settings.supabaseURL, anonKey: settings.anonKey, token: clientToken(user: user))
            try await client.upsertUserMeta(userId: user.id, schema: settings.schemaVersion, envelope: envelope)
            lastSyncedAt = Date()
            lastError = nil
        } catch {
            lastError = "上传失败：\(error.localizedDescription)"
        }
    }

    /// Pull server state into a fresh envelope (or nil if not present).
    func pull(user: SyncUser) async -> SyncEnvelope? {
        guard settings.isConfigured else { return nil }
        isSyncing = true
        defer { isSyncing = false }
        do {
            let client = try SupabaseClient(url: settings.supabaseURL, anonKey: settings.anonKey, token: clientToken(user: user))
            let envelope = try await client.fetchUserMeta(userId: user.id, schema: settings.schemaVersion)
            lastSyncedAt = Date()
            lastError = nil
            return envelope
        } catch {
            lastError = "拉取失败：\(error.localizedDescription)"
            return nil
        }
    }

    /// The session token for the current user (in a real impl we'd persist the JWT).
    /// For this MVP we re-authenticate on every sync via stored password is not viable;
    /// instead we keep an in-memory token captured at signIn.
    private var tokenCache: String?

    private func clientToken(user: SyncUser) -> String {
        if let t = tokenCache { return t }
        // For MVP: anon-key-only writes require RLS policies that allow write by user.
        // Returning the anon key means writes must be allowed via RLS — see Settings README.
        return settings.anonKey
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