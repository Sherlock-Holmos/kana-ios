import SwiftUI

struct ProgressViewScreen: View {
    @EnvironmentObject private var srsStore: SRSStore
    @EnvironmentObject private var ability: AbilityProfile

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
                        row("阅读", value: counts.reading)
                        row("听力", value: counts.listening)
                        row("题目变体", value: counts.questionVariants)
                    } else {
                        ProgressView()
                    }
                }

                Section("SRS 复习") {
                    row("已跟踪卡片", value: srsStore.totalTracked)
                    row("累计复习次数", value: srsStore.totalReviews)
                    row("累计遗忘次数", value: srsStore.totalLapses)
                    row("当前到期", value: srsStore.dueItems().count)
                }

                if !ability.abilities.isEmpty {
                    Section("能力画像") {
                        let top = ability.abilities.values.sorted { $0.mastery > $1.mastery }.prefix(6)
                        ForEach(Array(top), id: \.id) { ab in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(ab.id)
                                        .font(.caption.monospaced())
                                    Spacer()
                                    Text(String(format: "%.0f%%", ab.mastery * 100))
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(masteryColor(ab.mastery))
                                }
                                ProgressView(value: ab.mastery)
                                    .tint(masteryColor(ab.mastery))
                            }
                            .padding(.vertical, 2)
                        }
                    }
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

    private func masteryColor(_ v: Double) -> Color {
        if v >= 0.8 { return .green }
        if v >= 0.5 { return .blue }
        return .orange
    }

    private func load() async {
        counts = try? ContentService.shared.counts()
    }
}