import Foundation
import Combine

/// SyncSettings — persisted Supabase project URL + anon key.
/// Defaults to the kana-study web project's Supabase instance so the iOS app
/// can sync out of the box without the user having to configure anything.
final class SyncSettings: ObservableObject {
    /// Default Supabase project URL — shared with kana-study web app.
    static let defaultSupabaseURL = "https://actgbctprjohjqhxwvlz.supabase.co"
    /// Default Supabase publishable key — same as kana-study web app (safe for client use).
    static let defaultAnonKey = "sb_publishable_g2TZB_-n02_IDT3tVpHhNA_-8yAUxEy"

    @Published var supabaseURL: String {
        didSet { defaults.set(supabaseURL, forKey: urlKey) }
    }
    @Published var anonKey: String {
        didSet { defaults.set(anonKey, forKey: keyKey) }
    }
    @Published var userEmail: String {
        didSet { defaults.set(userEmail, forKey: emailKey) }
    }
    @Published var schemaVersion: Int {
        didSet { defaults.set(schemaVersion, forKey: schemaKey) }
    }

    private let urlKey = "kana-study.sync.url"
    private let keyKey = "kana-study.sync.key"
    private let emailKey = "kana-study.sync.email"
    private let schemaKey = "kana-study.sync.schema"
    private let defaults = UserDefaults.standard

    init() {
        self.supabaseURL = defaults.string(forKey: urlKey) ?? Self.defaultSupabaseURL
        self.anonKey = defaults.string(forKey: keyKey) ?? Self.defaultAnonKey
        self.userEmail = defaults.string(forKey: emailKey) ?? ""
        self.schemaVersion = defaults.object(forKey: schemaKey) as? Int ?? 16
    }

    var isConfigured: Bool {
        !supabaseURL.isEmpty && !anonKey.isEmpty
    }

    /// True when the user has explicitly overridden the default credentials.
    var isUsingCustomBackend: Bool {
        supabaseURL != Self.defaultSupabaseURL || anonKey != Self.defaultAnonKey
    }

    func reset() {
        supabaseURL = Self.defaultSupabaseURL
        anonKey = Self.defaultAnonKey
        userEmail = ""
    }
}