import SwiftUI

struct LibraryView: View {
    @State private var counts: ContentService.Counts?

    var body: some View {
        NavigationStack {
            List {
                if let c = counts {
                    Section("基础") {
                        row("平假名 / 片假名", "\(c.kana) 项", icon: "character.book.closed.fill")
                        row("N5 词汇", "\(c.vocabulary) 项", icon: "textformat.abc")
                        row("N5 语法点", "\(c.grammar) 项", icon: "list.bullet.rectangle.fill")
                        row("N5 汉字", "\(c.kanji) 项", icon: "character.square.fill")
                    }
                    Section("技能") {
                        row("例句", "\(c.sentence) 句", icon: "text.bubble.fill")
                        row("阅读", "\(c.reading) 篇", icon: "doc.text.fill")
                        row("听力", "\(c.listening) 段", icon: "headphones")
                    }
                    Section("评估") {
                        row("Question Bank", "\(c.questionVariants) 变体", icon: "checkmark.seal.fill")
                    }
                } else {
                    ProgressView("加载中…")
                }
            }
            .navigationTitle("内容库")
            .task { await load() }
        }
    }

    private func row(_ title: String, _ subtitle: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.tint)
                .frame(width: 24)
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