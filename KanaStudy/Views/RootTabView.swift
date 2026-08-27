import SwiftUI

enum AppTab: Hashable {
    case home, learn, review, progress
}

struct RootTabView: View {
    @State private var selection: AppTab = .home

    var body: some View {
        TabView(selection: $selection) {
            HomeView(onJump: { selection = $0 })
                .tabItem { Label("我的", systemImage: "person.crop.circle.fill") }
                .tag(AppTab.home)

            LearnView()
                .tabItem { Label("学", systemImage: "book.fill") }
                .tag(AppTab.learn)

            ReviewView()
                .tabItem { Label("复习", systemImage: "arrow.clockwise") }
                .tag(AppTab.review)

            ProgressViewScreen()
                .tabItem { Label("进度", systemImage: "chart.bar.fill") }
                .tag(AppTab.progress)
        }
    }
}