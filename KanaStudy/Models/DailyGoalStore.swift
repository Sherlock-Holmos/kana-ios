import Foundation
import Combine

/// DailyGoalStore — tracks per-day review counts, streak length, and weekly heatmap.
/// Persisted in UserDefaults as a small JSON blob.
final class DailyGoalStore: ObservableObject {
    @Published private(set) var dailyGoal: Int = 20
    @Published private(set) var activityByDay: [String: Int] = [:]   // "yyyy-MM-dd" → count
    @Published private(set) var totalReviews: Int = 0

    // Daily Mission counters — keyed by "yyyy-MM-dd" so they auto-reset each day.
    @Published private(set) var learnedByDay: [String: Int] = [:]
    @Published private(set) var listeningByDay: [String: Int] = [:]
    @Published private(set) var readingByDay: [String: Int] = [:]

    /// Targets for the three Daily Mission rings on HomeView.
    static let dailyLearnTarget = 5
    static let dailyListenTarget = 1

    private let goalKey = "kana-study.daily.goal"
    private let activityKey = "kana-study.daily.activity.v1"
    private let learnedKey = "kana-study.daily.learned.v1"
    private let listeningKey = "kana-study.daily.listening.v1"
    private let readingKey = "kana-study.daily.reading.v1"
    private let defaults = UserDefaults.standard

    init() { load() }

    // MARK: - Public

    func setGoal(_ value: Int) {
        dailyGoal = max(1, min(value, 500))
        save()
    }

    func recordReview(count: Int = 1, at date: Date = Date()) {
        guard count > 0 else { return }
        let key = dayKey(date)
        activityByDay[key, default: 0] += count
        totalReviews += count
        save()
    }

    func recordLearned(count: Int = 1, at date: Date = Date()) {
        guard count > 0 else { return }
        learnedByDay[dayKey(date), default: 0] += count
        save()
    }

    func recordListening(at date: Date = Date()) {
        listeningByDay[dayKey(date), default: 0] += 1
        save()
    }

    func recordReading(at date: Date = Date()) {
        readingByDay[dayKey(date), default: 0] += 1
        save()
    }

    var learnedToday: Int { learnedByDay[dayKey(Date()), default: 0] }
    var listeningToday: Int { listeningByDay[dayKey(Date()), default: 0] }
    var readingToday: Int { readingByDay[dayKey(Date()), default: 0] }

    var missionReviewProgress: Double {
        guard dailyGoal > 0 else { return 0 }
        return min(1.0, Double(reviewsToday) / Double(dailyGoal))
    }

    var missionLearnProgress: Double {
        min(1.0, Double(learnedToday) / Double(Self.dailyLearnTarget))
    }

    var missionListenProgress: Double {
        min(1.0, Double(listeningToday + readingToday) / Double(Self.dailyListenTarget))
    }

    /// True once all three mission rings hit 100%.
    var dailyMissionComplete: Bool {
        missionReviewProgress >= 1.0 &&
        missionLearnProgress >= 1.0 &&
        missionListenProgress >= 1.0
    }

    var reviewsToday: Int {
        activityByDay[dayKey(Date()), default: 0]
    }

    var goalProgress: Double {
        guard dailyGoal > 0 else { return 0 }
        return min(1.0, Double(reviewsToday) / Double(dailyGoal))
    }

    var goalHitToday: Bool { reviewsToday >= dailyGoal }

    /// Consecutive days with activity (regardless of goal).
    var currentStreak: Int {
        var streak = 0
        var cursor = Date()
        let cal = Calendar.current
        while true {
            let key = dayKey(cursor)
            if (activityByDay[key] ?? 0) > 0 {
                streak += 1
                guard let prev = cal.date(byAdding: .day, value: -1, to: cursor) else { break }
                cursor = prev
            } else {
                break
            }
        }
        return streak
    }

    /// Consecutive days where the user hit their daily goal.
    var goalStreak: Int {
        var streak = 0
        var cursor = Date()
        let cal = Calendar.current
        while true {
            let key = dayKey(cursor)
            if (activityByDay[key] ?? 0) >= dailyGoal {
                streak += 1
                guard let prev = cal.date(byAdding: .day, value: -1, to: cursor) else { break }
                cursor = prev
            } else {
                break
            }
        }
        return streak
    }

    /// 12-week (84-day) heatmap ending today, oldest first.
    func heatmapLast12Weeks(today: Date = Date()) -> [HeatmapCell] {
        let cal = Calendar.current
        var cells: [HeatmapCell] = []
        for offset in (0..<84).reversed() {
            guard let date = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
            let key = dayKey(date)
            cells.append(HeatmapCell(date: date, count: activityByDay[key] ?? 0))
        }
        return cells
    }

    // MARK: - Persistence

    private func dayKey(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f.string(from: date)
    }

    private func load() {
        let stored = defaults.integer(forKey: goalKey)
        if stored > 0 { dailyGoal = stored }
        activityByDay = decodeIntDict(activityKey)
        learnedByDay  = decodeIntDict(learnedKey)
        listeningByDay = decodeIntDict(listeningKey)
        readingByDay   = decodeIntDict(readingKey)
        totalReviews = activityByDay.values.reduce(0, +)
    }

    private func save() {
        defaults.set(dailyGoal, forKey: goalKey)
        encodeIntDict(activityByDay, forKey: activityKey)
        encodeIntDict(learnedByDay,  forKey: learnedKey)
        encodeIntDict(listeningByDay, forKey: listeningKey)
        encodeIntDict(readingByDay,   forKey: readingKey)
        SyncTrigger.shared.bump()
    }

    private func decodeIntDict(_ key: String) -> [String: Int] {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([String: Int].self, from: data) else { return [:] }
        return decoded
    }

    private func encodeIntDict(_ dict: [String: Int], forKey key: String) {
        guard let encoded = try? JSONEncoder().encode(dict) else { return }
        defaults.set(encoded, forKey: key)
    }

    // MARK: - Server merge helpers

    /// Replace the activity-by-day dictionary (used when merging a server-side envelope).
    func replaceActivity(_ newActivity: [String: Int]) {
        activityByDay = newActivity
        totalReviews = newActivity.values.reduce(0, +)
        save()
    }
}

struct HeatmapCell: Identifiable, Hashable {
    let date: Date
    let count: Int
    var id: Date { date }
}