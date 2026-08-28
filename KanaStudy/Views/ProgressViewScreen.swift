import SwiftUI

struct ProgressViewScreen: View {
    @EnvironmentObject private var srsStore: SRSStore
    @EnvironmentObject private var bkt: BKTStore
    @EnvironmentObject private var goal: DailyGoalStore

    @State private var counts: ContentService.Counts?
    @State private var recommendations: [Planner.Recommendation] = []

    var body: some View {
        NavigationStack {
            List {
                Section("每日目标") {
                    HStack {
                        Text("今日复习")
                        Spacer()
                        Text("\(goal.reviewsToday) / \(goal.dailyGoal)")
                            .foregroundStyle(Color.textSecondary)
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
                            .foregroundStyle(Color.textSecondary)
                    }
                }

                Section("12 周热力图") {
                    HeatmapGrid(cells: goal.heatmapLast12Weeks())
                        .padding(.vertical, 6)
                }

                if !recommendations.isEmpty {
                    Section("BKT 自适应推荐") {
                        ForEach(recommendations) { rec in
                            HStack {
                                Image(systemName: "sparkles")
                                    .foregroundStyle(.tint)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(rec.id.abilityDisplayName)
                                        .font(.body.weight(.medium))
                                    if rec.id != rec.id.abilityDisplayName {
                                        Text(rec.id)
                                            .font(.caption2.monospaced())
                                            .foregroundStyle(Color.textTertiary)
                                    }
                                }
                                Spacer()
                                Text(rec.reason)
                                    .font(.caption)
                                    .padding(.horizontal, 8).padding(.vertical, 4)
                                    .background(Color.accentColor.opacity(0.15), in: Capsule())
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
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
                                    Text(m.abilityId.abilityDisplayName)
                                        .font(.callout.weight(.medium))
                                    Spacer()
                                    Text(String(format: "%.0f%%", m.pMaster * 100))
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(masteryColor(m.pMaster))
                                }
                                ProgressView(value: m.pMaster)
                                    .tint(masteryColor(m.pMaster))
                                HStack {
                                    Text(m.abilityId)
                                        .font(.caption2.monospaced())
                                        .foregroundStyle(Color.textTertiary)
                                    Spacer()
                                    Text("已答 \(m.opportunities) 次")
                                        .font(.caption2)
                                        .foregroundStyle(Color.textTertiary)
                                }
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
            Text("\(value)").foregroundStyle(Color.textSecondary)
        }
    }

    private func masteryColor(_ v: Double) -> Color {
        if v >= 0.8 { return .green }
        if v >= 0.5 { return .blue }
        return .orange
    }

    private func load() async {
        counts = try? await ContentService.shared.counts()
        if let kana = try? await ContentService.shared.loadKana(),
           let vocab = try? await ContentService.shared.loadVocabulary() {
            recommendations = Planner(srs: srsStore, bkt: bkt, goal: goal)
                .recommend(limit: 6, kana: kana, vocab: vocab)
        }
    }
}

// MARK: - Heatmap

struct HeatmapGrid: View {
    let cells: [HeatmapCell]
    private let columns = 12
    private let cellSize: CGFloat = 16
    private let cellSpacing: CGFloat = 3
    private let weekdayLabels = ["", "一", "", "三", "", "五", ""]   // 7 rows; labels for Mon/Wed/Fri

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(0..<7, id: \.self) { row in
                HStack(spacing: cellSpacing) {
                    Text(weekdayLabels[row])
                        .font(.system(size: 9))
                        .foregroundStyle(Color.textTertiary)
                        .frame(width: 14, alignment: .trailing)
                    ForEach(0..<columns, id: \.self) { col in
                        let index = row * columns + col
                        if index < cells.count {
                            HeatmapCellView(cell: cells[index])
                                .frame(width: cellSize, height: cellSize)
                        } else {
                            Color.clear
                                .frame(width: cellSize, height: cellSize)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
            legend
                .padding(.top, 6)
        }
    }

    private var legend: some View {
        HStack(spacing: 6) {
            Text("少")
                .font(.caption2)
                .foregroundStyle(Color.textTertiary)
            ForEach(intensityColors, id: \.self) { color in
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: 10, height: 10)
            }
            Text("多")
                .font(.caption2)
                .foregroundStyle(Color.textTertiary)
            Spacer()
            Text("\(cells.count) 天")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(Color.textTertiary)
        }
    }

    private var intensityColors: [Color] {
        [
            HeatmapCellView.color(forCount: 0),
            HeatmapCellView.color(forCount: 3),
            HeatmapCellView.color(forCount: 10),
            HeatmapCellView.color(forCount: 20),
            HeatmapCellView.color(forCount: 30)
        ]
    }
}

struct HeatmapCellView: View {
    let cell: HeatmapCell

    var body: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(color)
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(Color(.separator).opacity(0.3), lineWidth: 0.5)
            )
    }

    fileprivate var color: Color {
        Self.color(forCount: cell.count)
    }

    /// Map a per-day review count to a heatmap color.
    /// Empty days now use a slightly tinted background so the grid is visible
    /// against the Form/Section row background.
    static func color(forCount count: Int) -> Color {
        if count == 0  { return Color(.systemGray6) }
        if count >= 30 { return .green }
        if count >= 15 { return Color.green.opacity(0.7) }
        if count >= 5  { return Color.green.opacity(0.4) }
        if count >= 1  { return Color.green.opacity(0.22) }
        return Color(.systemGray6)
    }
}