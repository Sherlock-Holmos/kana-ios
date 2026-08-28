import SwiftUI

@main
struct KanaStudyApp: App {
    @StateObject private var srsStore = SRSStore()
    @StateObject private var abilityProfile = AbilityProfile()
    @StateObject private var bktStore = BKTStore()
    @StateObject private var dailyGoal = DailyGoalStore()
    @StateObject private var syncSettings = SyncSettings()
    @StateObject private var syncService = SyncService.shared

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(srsStore)
                .environmentObject(abilityProfile)
                .environmentObject(bktStore)
                .environmentObject(dailyGoal)
                .environmentObject(syncSettings)
                .environmentObject(syncService)
                .task {
                    srsStore.goalStore = dailyGoal
                    syncService.attach(
                        srs: srsStore,
                        bkt: bktStore,
                        ability: abilityProfile,
                        goal: dailyGoal
                    )
                    // Fire-and-forget warm of the two heaviest content collections so
                    // the first navigation into Learn / Review / Progress hits cache
                    // instead of paying a JSON parse on the main thread. Detached so
                    // the launch task returns immediately — warmup never blocks UI.
                    Task.detached(priority: .userInitiated) {
                        async let kana: Void = ContentService.shared.warmKana()
                        async let vocab: Void = ContentService.shared.warmVocabulary()
                        _ = await (kana, vocab)
                    }
                }
        }
    }
}