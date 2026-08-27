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

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                summary

                if let error {
                    Text(error).foregroundStyle(.red)
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
            } else {
                Button("显示答案") { revealed = true }
                    .buttonStyle(.bordered)
                    .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 260)
        .padding(20)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
    }

    private func gradeButtons(id: String) -> some View {
        HStack(spacing: 8) {
            ForEach(SRSGrade.allCases) { grade in
                Button {
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
                } label: {
                    Text(grade.label)
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(color(for: grade))
            }
        }
    }

    private func color(for grade: SRSGrade) -> Color {
        switch grade {
        case .again: return .red
        case .hard:  return .orange
        case .good:  return .blue
        case .easy:  return .green
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