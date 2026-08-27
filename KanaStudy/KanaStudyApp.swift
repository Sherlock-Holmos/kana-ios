import SwiftUI

@main
struct KanaStudyApp: App {
    @StateObject private var srsStore = SRSStore()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(srsStore)
        }
    }
}