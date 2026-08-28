import SwiftUI

/// DailyMissionCard — three progress rings the user fills out each day.
/// Apple's Daily Habits pattern (Fitness rings, Duolingo streak) distilled:
/// one tap each ring jumps to the relevant tab.
struct DailyMissionCard: View {
    @EnvironmentObject private var goal: DailyGoalStore

    let onTapReview: () -> Void
    let onTapLearn:  () -> Void
    let onTapListen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("今日任务")
                    .font(.headline)
                Spacer()
                if goal.dailyMissionComplete {
                    Label("已完成", systemImage: "checkmark.seal.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.green, in: Capsule())
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: goal.dailyMissionComplete)

            HStack(spacing: 12) {
                missionRing(
                    icon: "arrow.clockwise",
                    title: "复习",
                    progress: goal.missionReviewProgress,
                    label: "\(goal.reviewsToday) / \(goal.dailyGoal)",
                    tint: .red,
                    action: onTapReview
                )
                missionRing(
                    icon: "sparkles",
                    title: "学新",
                    progress: goal.missionLearnProgress,
                    label: "\(goal.learnedToday) / \(DailyGoalStore.dailyLearnTarget)",
                    tint: .green,
                    action: onTapLearn
                )
                missionRing(
                    icon: "headphones",
                    title: "听读",
                    progress: goal.missionListenProgress,
                    label: "\(goal.listeningToday + goal.readingToday) / \(DailyGoalStore.dailyListenTarget)",
                    tint: .blue,
                    action: onTapListen
                )
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private func missionRing(
        icon: String,
        title: String,
        progress: Double,
        label: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .stroke(Color(.tertiarySystemBackground), lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: max(0.001, min(1, progress)))
                        .stroke(tint, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(progress >= 1.0 ? .white : tint)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle().fill(progress >= 1.0 ? tint : tint.opacity(0.12))
                        )
                }
                .frame(width: 64, height: 64)

                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(label)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(Color.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}