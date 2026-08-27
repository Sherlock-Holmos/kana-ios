import SwiftUI

struct ProgressViewScreen: View {
    @EnvironmentObject private var srsStore: SRSStore
    @EnvironmentObject private var ability: AbilityProfile
    @EnvironmentObject private var bkt: BKTStore
    @EnvironmentObject private var goal: DailyGoalStore

    @State private var counts: ContentService.Counts?

    var body: some View {
        NavigationStack {
            List {
                Section("每日目标") {
                    HStack {
                        Text("今日复习")
                        Spacer()
                        Text("\(goal.reviewsToday) / \(goal.dailyGoal)")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("连续天数")
                        Spacer()
                        Text("\(goal.currentStreak)")
                            .foregroundStyle(.orange)
                    }
                    HStack {
                        Text("达成连续")
                        Spacer()
                        Text("\(goal.goalStreak)")
                            .foregroundStyle(.green)
                    }
                    HStack {
                        Text("累计复习")
                        Spacer()
                        Text("\(goal.totalReviews)")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("12 周热力图") {
                    HeatmapGrid(cells: goal.heatmapLast12Weeks())
                        .frame(height: 120)
                }

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

                if !bkt.masteries.isEmpty {
                    Section("BKT 能力画像") {
                        let top = bkt.masteries.values.sorted { $0.pMaster > $1.pMaster }.prefix(8)
                        ForEach(Array(top), id: \.abilityId) { m in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(m.abilityId)
                                        .font(.caption.monospaced())
                                    Spacer()
                                    Text(String(format: "%.0f%%", m.pMaster * 100))
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(masteryColor(m.pMaster))
                                }
                                ProgressView(value: m.pMaster)
                                    .tint(masteryColor(m.pMaster))
                                Text("已答 \(m.opportunities) 次")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                if !ability.abilities.isEmpty {
                    Section("能力画像（旧版 Bayesian）") {
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

// MARK: - Heatmap

struct HeatmapGrid: View {
    let cells: [HeatmapCell]
    private let columns = 12

    var body: some View {
        let rows = stride(from: 0, to: cells.count, by: columns).map {
            Array(cells[$0..<min($0 + columns, cells.count)])
        }

        GeometryReader { geo in
            let side = min(geo.size.width / CGFloat(columns), geo.size.height / CGFloat(rows.count))
            VStack(spacing: 2) {
                ForEach(0..<rows.count, id: \.self) { r in
                    HStack(spacing: 2) {
                        ForEach(0..<rows[r].count, id: \.self) { c in
                            HeatmapCellView(cell: rows[r][c])
                                .frame(width: side, height: side)
                        }
                    }
                }
            }
        }
    }
}

struct HeatmapCellView: View {
    let cell: HeatmapCell

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(color)
    }

    private var color: Color {
        if cell.count == 0 { return Color(.tertiarySystemBackground) }
        if cell.count >= 30 { return .green }
        if cell.count >= 15 { return Color.green.opacity(0.6) }
        if cell.count >= 5  { return Color.green.opacity(0.35) }
        return Color.green.opacity(0.18)
    }
}