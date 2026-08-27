import SwiftUI

struct LibraryView: View {
    @State private var counts: ContentService.Counts?

    var body: some View {
        NavigationStack {
            List {
                if let c = counts {
                    Section("假名") {
                        row("平假名 / 片假名", "\(c.kana) 项")
                    }
                    Section("词汇") {
                        row("N5 词汇", "\(c.vocabulary) 项")
                    }
                    Section("语法") {
                        row("N5 语法点", "\(c.grammar) 项")
                    }
                    Section("汉字") {
                        row("N5 汉字", "\(c.kanji) 项")
                    }
                    Section("例句") {
                        row("带读音与翻译", "\(c.sentence) 句")
                    }
                } else {
                    ProgressView("加载中…")
                }
            }
            .navigationTitle("内容库")
            .task { await load() }
        }
    }

    private func row(_ title: String, _ subtitle: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(subtitle)
                .foregroundStyle(.secondary)
        }
    }

    private func load() async {
        counts = try? ContentService.shared.counts()
    }
}