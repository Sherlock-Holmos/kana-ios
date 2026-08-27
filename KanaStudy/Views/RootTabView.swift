import SwiftUI

enum AppTab: Hashable {
    case home, learn, review, library, progress
}

struct RootTabView: View {
    @State private var selection: AppTab = .home

    var body: some View {
        TabView(selection: $selection) {
            Tab("首页", systemImage: "house.fill", value: AppTab.home) {
                HomeView(onJump: { selection = $0 })
            }
            Tab("学习", systemImage: "book.fill", value: AppTab.learn) {
                LearnView()
            }
            Tab("复习", systemImage: "arrow.clockwise", value: AppTab.review) {
                ReviewView()
            }
            Tab("内容库", systemImage: "books.vertical.fill", value: AppTab.library) {
                LibraryView()
            }
            Tab("进度", systemImage: "chart.bar.fill", value: AppTab.progress) {
                ProgressViewScreen()
            }
        }
    }
}