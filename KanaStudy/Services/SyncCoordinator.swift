import Foundation
import Combine

/// SyncCoordinator — owns the wiring between the four local stores, the
/// auth service, and the network transport. Subscribes to SyncTrigger
/// and pushes the merged envelope on a 1.2s debounce so rapid-fire taps
/// collapse into a single round-trip.
@MainActor
final class SyncCoordinator {

    let auth: AuthService
    let settings: SyncSettings

    /// Last completed push/pull timestamp. Read by SyncService for the UI.
    @Published private(set) var lastSyncedAt: Date?
    /// Most recent error message. Cleared on the next successful round-trip.
    @Published private(set) var lastError: String?
    /// True while a push or pull is in flight.
    @Published private(set) var isSyncing: Bool = false

    // Wired stores (weak so the stores don't get retained by the coordinator).
    private weak var srsStore: SRSStore?
    private weak var bktStore: BKTStore?
    private weak var abilityStore: AbilityProfile?
    private weak var goalStore: DailyGoalStore?

    private var cancellables = Set<AnyCancellable>()
    private var hasAttached = false

    init(auth: AuthService, settings: SyncSettings) {
        self.auth = auth
        self.settings = settings
    }

    /// Wire coordinator to the four local stores. Called once from the App entry.
    /// After attach, every store mutation triggers a debounced push.
    func attach(srs: SRSStore, bkt: BKTStore, ability: AbilityProfile, goal: DailyGoalStore) {
        guard !hasAttached else { return }
        hasAttached = true
        self.srsStore = srs
        self.bktStore = bkt
        self.abilityStore = ability
        self.goalStore = goal

        // Pull from server on first attach (after Keychain-restored login) so a fresh
        // install of a returning user lands with their progress already populated.
        if auth.isSignedIn {
            Task { await self.pullAndMerge() }
        }

        // Listen for store mutations and push the merged envelope with a 1.2s debounce
        // so rapid-fire taps batch into a single network call.
        SyncTrigger.shared.subject
            .debounce(for: .seconds(1.2), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { await self?.pushCurrent() }
            }
            .store(in: &cancellables)
    }

    var isReady: Bool {
        settings.isConfigured && auth.isSignedIn
    }

    // MARK: - Auth flow

    /// Sign in against Supabase, then hydrate this device with the user's
    /// existing cloud progress and push the local snapshot so the server
    /// sees any drift accumulated while logged out.
    func signIn(email: String, password: String) async {
        guard settings.isConfigured else {
            lastError = "未配置 Supabase URL 或 anon key"
            return
        }
        do {
            let session = try await auth.signIn(
                url: settings.supabaseURL,
                anonKey: settings.anonKey,
                email: email,
                password: password
            )
            settings.userEmail = session.user.email
            lastError = nil
            await pullAndMerge()
            await pushCurrent()
        } catch {
            lastError = "登录失败：\(error.localizedDescription)"
        }
    }

    /// Register a brand-new account, then push the local snapshot up so the
    /// first sync isn't empty.
    func signUp(email: String, password: String) async {
        guard settings.isConfigured else {
            lastError = "未配置 Supabase URL 或 anon key"
            return
        }
        do {
            let session = try await auth.signUp(
                url: settings.supabaseURL,
                anonKey: settings.anonKey,
                email: email,
                password: password
            )
            settings.userEmail = session.user.email
            lastError = nil
            await pushCurrent()
        } catch {
            lastError = "注册失败：\(error.localizedDescription)"
        }
    }

    // MARK: - Sync operations

    /// Build an envelope from the four attached stores and push it.
    /// No-op when not signed in or when stores aren't attached yet.
    func pushCurrent() async {
        guard let srs = srsStore,
              let bkt = bktStore,
              let ability = abilityStore,
              let goal = goalStore else { return }
        guard let user = auth.currentUser,
              let token = auth.accessToken else { return }
        let envelope = SyncEnvelope.make(srs: srs, bkt: bkt, ability: ability, goal: goal)
        await push(envelope: envelope, user: user, token: token)
    }

    /// Push a specific envelope (used after a fresh sign-in to seed the server).
    func push(envelope: SyncEnvelope, user: SyncUser, token: String) async {
        guard settings.isConfigured else { return }
        isSyncing = true
        defer { isSyncing = false }
        do {
            let transport = SyncTransport(url: settings.supabaseURL, anonKey: settings.anonKey)
            try await transport.push(envelope: envelope, user: user, token: token, schema: settings.schemaVersion)
            lastSyncedAt = Date()
            lastError = nil
        } catch {
            lastError = "上传失败：\(error.localizedDescription)"
        }
    }

    /// Pull the current user's envelope and merge it into the four attached stores.
    /// Called on attach (returning user) and after a fresh sign-in.
    func pullAndMerge() async {
        guard let user = auth.currentUser,
              let token = auth.accessToken,
              let srs = srsStore,
              let bkt = bktStore,
              let ability = abilityStore,
              let goal = goalStore else { return }
        guard settings.isConfigured else { return }
        isSyncing = true
        defer { isSyncing = false }
        do {
            let transport = SyncTransport(url: settings.supabaseURL, anonKey: settings.anonKey)
            if let envelope = try await transport.pull(user: user, token: token, schema: settings.schemaVersion) {
                envelope.merge(into: srs, bkt: bkt, ability: ability, goal: goal)
            }
            lastSyncedAt = Date()
            lastError = nil
        } catch {
            lastError = "拉取失败：\(error.localizedDescription)"
        }
    }
}