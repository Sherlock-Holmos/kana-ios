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
                }
        }
    }
}