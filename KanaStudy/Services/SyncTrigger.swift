import Foundation
import Combine

/// SyncTrigger — a tiny pub/sub the local stores fire after every state mutation.
/// SyncService listens and pushes the next envelope to Supabase (debounced).
///
/// Stores stay completely decoupled from SyncService: they only know about this
/// trigger, never about HTTP, auth, or other stores.
final class SyncTrigger {
    static let shared = SyncTrigger()

    /// Fires once per logical mutation. Subscribers should debounce.
    let subject = PassthroughSubject<Void, Never>()

    private init() {}

    func bump() { subject.send() }
}
