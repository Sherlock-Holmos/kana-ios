import SwiftUI

@main
struct KanaStudyApp: App {
    @StateObject private var srsStore = SRSStore()
    @StateObject private var abilityProfile = AbilityProfile()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(srsStore)
                .environmentObject(abilityProfile)
        }
    }
}