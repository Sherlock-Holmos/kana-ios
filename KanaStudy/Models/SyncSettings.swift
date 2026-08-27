import Foundation
import Combine

/// SyncSettings — persisted Supabase project URL + anon key.
/// When unset, the app runs in fully-local mode; SyncService becomes a no-op.
final class SyncSettings: ObservableObject {
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
        self.supabaseURL = defaults.string(forKey: urlKey) ?? ""
        self.anonKey = defaults.string(forKey: keyKey) ?? ""
        self.userEmail = defaults.string(forKey: emailKey) ?? ""
        self.schemaVersion = defaults.object(forKey: schemaKey) as? Int ?? 16
    }

    var isConfigured: Bool {
        !supabaseURL.isEmpty && !anonKey.isEmpty
    }

    func reset() {
        supabaseURL = ""
        anonKey = ""
        userEmail = ""
    }
}