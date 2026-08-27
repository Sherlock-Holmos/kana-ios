import SwiftUI

struct ReviewView: View {
    @EnvironmentObject private var srsStore: SRSStore
    @EnvironmentObject private var ability: AbilityProfile
    @EnvironmentObject private var bkt: BKTStore
    @EnvironmentObject private var goal: DailyGoalStore

    @State private var kanaItems: [KanaItem] = []
    @State private var vocabItems: [VocabularyItem] = []
    @State private var currentId: String?
    @State private var revealed: Bool = false
    @State private var error: String?
    @State private var dragOffset: CGSize = .zero
    @State private var successTrigger = 0
    @State private var errorTrigger = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                summary

                if let error {
                    ErrorView(error, retry: { Task { await prepare() } })
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                if let id = currentId, let snapshot = snapshot(for: id) {
                    cardView(snapshot)
                    gradeButtons(id: id)
                } else {
                    emptyState
                }

                Spacer()
            }
            .padding()
            .navigationTitle("复习")
            .task { await prepare() }
            .sensoryFeedback(.success, trigger: successTrigger)
            .sensoryFeedback(.error, trigger: errorTrigger)
        }
    }

    // MARK: - Summary

    private var summary: some View {
        let due = srsStore.dueItems().count
        return HStack(spacing: 10) {
            stat("到期", value: due)
            stat("已跟踪", value: srsStore.totalTracked)
            stat("今日", value: goal.reviewsToday)
            stat("连续", value: goal.currentStreak)
        }
    }

    private func stat(_ label: String, value: Int) -> some View {
        VStack(spacing: 4) {
            Text("\(value)").font(.title3.bold())
            Text(label).font(.caption).foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Card snapshot

    private struct CardSnapshot {
        let display: String
        let subtitle: String
        let back: String
        let abilities: [String]
    }

    private func snapshot(for id: String) -> CardSnapshot? {
        if let k = kanaItems.first(where: { $0.id == id }) {
            return CardSnapshot(
                display: k.kana,
                subtitle: k.isHiragana ? "平假名" : "片假名",
                back: "\(k.roman)\(k.memory.map { " — \($0)" } ?? "")",
                abilities: ["kana.recognition", "kana.recall"]
            )
        }
        if let v = vocabItems.first(where: { $0.id == id }) {
            return CardSnapshot(
                display: v.expression,
                subtitle: v.reading,
                back: v.primaryMeaning,
                abilities: ["vocabulary.meaning", "vocabulary.reading", "vocabulary.production"]
            )
        }
        return nil
    }

    // MARK: - Card UI

    private func cardView(_ s: CardSnapshot) -> some View {
        VStack(spacing: 12) {
            Text(s.display)
                .font(.system(size: 64, weight: .medium, design: .serif))
            Text(s.subtitle)
                .font(.title3)
                .foregroundStyle(Color.textSecondary)
            if revealed {
                Divider().padding(.vertical, 6)
                Text(s.back)
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                swipeLegend
                    .padding(.top, 6)
            } else {
                Button("显示答案") { revealed = true }
                    .buttonStyle(.bordered)
                    .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 260)
        .padding(20)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
        .overlay(swipeHint)
        .offset(dragOffset)
        .opacity(1 - min(1, Double(abs(dragOffset.width)) / 220.0))
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: dragOffset)
        .gesture(swipeGesture)
    }

    @ViewBuilder
    private var swipeHint: some View {
        if revealed {
            let dx = Double(dragOffset.width)
            let dy = Double(dragOffset.height)
            HStack {
                if dx < -40 { hintChip("重来", color: .red,   icon: "arrow.left") }
                if dx > 40  { hintChip("记得", color: .blue,  icon: "arrow.right") }
                Spacer()
                if dy > 40  { hintChip("困难", color: .orange, icon: "arrow.down") }
                if dy < -40 { hintChip("简单", color: .green, icon: "arrow.up") }
            }
            .font(.caption.bold())
            .padding(.horizontal, 4)
        }
    }

    private func hintChip(_ text: String, color: Color, icon: String) -> some View {
        Label(text, systemImage: icon)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.18), in: Capsule())
            .foregroundStyle(color)
    }

    private var swipeLegend: some View {
        HStack(spacing: 6) {
            miniArrow("←", "重来", .red)
            miniArrow("↓", "困难", .orange)
            miniArrow("↑", "简单", .green)
            miniArrow("→", "记得", .blue)
        }
        .font(.caption2)
    }

    private func miniArrow(_ symbol: String, _ text: String, _ color: Color) -> some View {
        HStack(spacing: 2) {
            Text(symbol).bold().foregroundStyle(color)
            Text(text).foregroundStyle(Color.textSecondary)
        }
    }

    private var swipeGesture: some Gesture {
        DragGesture()
            .onChanged { v in dragOffset = v.translation }
            .onEnded { v in
                defer {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        dragOffset = .zero
                    }
                }
                guard revealed, let id = currentId else { return }
                let dx = v.translation.width
                let dy = v.translation.height
                let threshold: CGFloat = 80
                let action: SRSGrade?
                if abs(dx) > abs(dy) {
                    action = dx < -threshold ? .again : dx > threshold ? .good : nil
                } else {
                    action = dy < -threshold ? .easy : dy > threshold ? .hard : nil
                }
                if let g = action { applyGrade(id, as: g) }
            }
    }

    private func gradeButtons(id: String) -> some View {
        HStack(spacing: 8) {
            ForEach(SRSGrade.allCases) { grade in
                Button {
                    applyGrade(id, as: grade)
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: directionSymbol(grade))
                            .font(.caption2)
                            .opacity(0.8)
                        Text(grade.label)
                            .font(.subheadline.bold())
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(color(for: grade))
            }
        }
    }

    private func applyGrade(_ id: String, as grade: SRSGrade) {
        let success = grade != .again
        srsStore.grade(id, as: grade)
        if let snapshot = snapshot(for: id) {
            ability.recordOutcomes(snapshot.abilities, success: success)
            for ab in snapshot.abilities {
                bkt.update(abilityId: ab, correct: success)
            }
        }
        goal.recordReview()
        revealed = false
        advance()
        if success { successTrigger += 1 } else { errorTrigger += 1 }
    }

    private func color(for grade: SRSGrade) -> Color {
        switch grade {
        case .again: return .red
        case .hard:  return .orange
        case .good:  return .blue
        case .easy:  return .green
        }
    }

    private func directionSymbol(_ grade: SRSGrade) -> String {
        switch grade {
        case .again: return "arrow.left"
        case .good:  return "arrow.right"
        case .easy:  return "arrow.up"
        case .hard:  return "arrow.down"
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            Text("今天没有到期卡片")
                .font(.title3.bold())
            Text("去「学习」里找新内容记一遍，下一次复习会自动排上。")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.textSecondary)
                .padding(.horizontal)
        }
        .padding(.top, 32)
    }

    private func advance() {
        let due = srsStore.dueItems()
        if let next = due.first {
            currentId = next.id
            revealed = false
        } else {
            currentId = nil
        }
    }

    private func prepare() async {
        do {
            kanaItems = try ContentService.shared.loadKana()
            vocabItems = try ContentService.shared.loadVocabulary()
            error = nil
            seedIfNeeded()
            advance()
        } catch {
            self.error = "复习内容加载失败：\(error)"
        }
    }

    private func seedIfNeeded() {
        guard srsStore.totalTracked == 0 else { return }
        for k in kanaItems.prefix(20) { srsStore.enroll(k.id) }
        for v in vocabItems.prefix(20) { srsStore.enroll(v.id) }
    }
}