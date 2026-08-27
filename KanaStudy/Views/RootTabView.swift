import SwiftUI

enum AppTab: Hashable {
    case home, learn, review, library, progress
}

struct RootTabView: View {
    @State private var selection: AppTab = .home

    var body: some View {
        TabView(selection: $selection) {
            HomeView(onJump: { selection = $0 })
                .tabItem { Label("首页", systemImage: "house.fill") }
                .tag(AppTab.home)

            LearnView()
                .tabItem { Label("学习", systemImage: "book.fill") }
                .tag(AppTab.learn)

            ReviewView()
                .tabItem { Label("复习", systemImage: "arrow.clockwise") }
                .tag(AppTab.review)

            LibraryView()
                .tabItem { Label("内容库", systemImage: "books.vertical.fill") }
                .tag(AppTab.library)

            ProgressViewScreen()
                .tabItem { Label("进度", systemImage: "chart.bar.fill") }
                .tag(AppTab.progress)
        }
    }
}