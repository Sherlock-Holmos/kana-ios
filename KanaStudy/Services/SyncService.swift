import Foundation
import Combine

// MARK: - Sync Models (kept here so SyncEnvelope / SyncUser / AnyCodable live with
// the model that originally owned them — no view or other service depends on their
// physical location, only on SyncService / SyncEnvelope being available.)

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

    /// Build a fresh envelope from the four local stores.
    static func make(srs: SRSStore, bkt: BKTStore, ability: AbilityProfile, goal: DailyGoalStore) -> SyncEnvelope {
        SyncEnvelope(
            meta: nil,
            srsCards: srs.cards,
            abilities: ability.abilities,
            activityByDay: goal.activityByDay,
            dailyGoal: goal.dailyGoal,
            bktMasteries: bkt.masteries,
            updatedAt: Date()
        )
    }

    /// Merge this server-side envelope into the local stores (last-write-wins per field).
    /// Used after a successful sign-in to hydrate the device with the user's progress.
    func merge(into srs: SRSStore, bkt: BKTStore, ability: AbilityProfile, goal: DailyGoalStore) {
        if let cards = srsCards { srs.replaceAll(cards) }
        if let abs = abilities { ability.replaceAll(abs) }
        if let acts = activityByDay { goal.replaceActivity(acts) }
        if let g = dailyGoal { goal.setGoal(g) }
        if let ms = bktMasteries { bkt.replaceAll(ms) }
    }
}

// MARK: - SyncService (facade)

/// SyncService — thin facade preserved for view-layer compatibility.
/// The actual work is delegated to three single-responsibility components:
///   • AuthService    — JWT / Keychain / currentUser
///   • SyncTransport  — pure HTTP push/pull
///   • SyncCoordinator — wires stores + debounce subscription + envelope flow
///
/// Views continue to call `sync.signIn`, read `sync.currentUser`, etc.
/// Adding a new sync capability now means editing one of the three inner
/// services instead of this 280-line god object.
@MainActor
final class SyncService: ObservableObject {

    /// Backwards-compatible shared instance. KanaStudyApp constructs SyncService
    /// through `SyncService.shared`; new code should inject AuthService / SyncCoordinator
    /// directly when feasible.
    static let shared = SyncService(auth: AuthService(), settings: SyncSettings())

    let auth: AuthService
    let coordinator: SyncCoordinator

    /// Exposed for SettingsView so users can override the Supabase URL / anon key.
    let settings: SyncSettings

    // MARK: - Passthrough UI state

    /// Currently-signed-in user, mirrored from AuthService.
    var currentUser: SyncUser? { auth.currentUser }

    /// Last successful push or pull.
    var lastSyncedAt: Date? { coordinator.lastSyncedAt }

    /// Most recent sync error message.
    var lastError: String? { coordinator.lastError }

    /// True while a push or pull is in flight.
    var isSyncing: Bool { coordinator.isSyncing }

    /// True when configured AND signed in.
    var isReady: Bool { coordinator.isReady }

    // MARK: - Init

    init(auth: AuthService, settings: SyncSettings) {
        self.auth = auth
        self.settings = settings
        self.coordinator = SyncCoordinator(auth: auth, settings: settings)
    }

    /// Wire SyncService to the four local stores. Called once from the App entry.
    /// After attach, every store mutation triggers a debounced push.
    func attach(srs: SRSStore, bkt: BKTStore, ability: AbilityProfile, goal: DailyGoalStore) {
        coordinator.attach(srs: srs, bkt: bkt, ability: ability, goal: goal)
    }

    // MARK: - Auth (forwarded)

    func signIn(email: String, password: String) async {
        await coordinator.signIn(email: email, password: password)
    }

    func signUp(email: String, password: String) async {
        await coordinator.signUp(email: email, password: password)
    }

    func signOut() {
        auth.signOut()
        settings.userEmail = ""
    }

    // MARK: - Sync (forwarded)

    /// Build an envelope from the four attached stores and push it.
    /// No-op when not signed in or when stores aren't attached yet.
    func pushCurrent() async {
        await coordinator.pushCurrent()
    }

    /// Pull the current user's envelope and merge it into the four attached stores.
    func pullAndMerge() async {
        await coordinator.pullAndMerge()
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