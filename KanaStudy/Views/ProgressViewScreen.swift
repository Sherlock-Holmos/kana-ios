import SwiftUI

struct ProgressViewScreen: View {
    @EnvironmentObject private var srsStore: SRSStore
    @State private var counts: ContentService.Counts?

    var body: some View {
        NavigationStack {
            List {
                Section("学习进度") {
                    if let counts {
                        row("已收录内容", value: counts.kana + counts.vocabulary + counts.grammar + counts.kanji + counts.sentence)
                        row("假名", value: counts.kana)
                        row("词汇", value: counts.vocabulary)
                        row("语法", value: counts.grammar)
                        row("汉字", value: counts.kanji)
                        row("例句", value: counts.sentence)
                    } else {
                        ProgressView()
                    }
                }

                Section("SRS 复习") {
                    row("已跟踪卡片", value: srsStore.totalTracked)
                    row("累计复习次数", value: srsStore.totalReviews)
                    row("当前到期", value: srsStore.dueItems().count)
                }

                Section {
                    Text("当前为本地追踪。后续会接 Supabase 同步与 Speaking Foundation。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("进度")
            .task { await load() }
        }
    }

    private func row(_ title: String, value: Int) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text("\(value)").foregroundStyle(.secondary)
        }
    }

    private func load() async {
        counts = try? ContentService.shared.counts()
    }
}