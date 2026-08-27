import Foundation
import Combine

/// DailyGoalStore — tracks per-day review counts, streak length, and weekly heatmap.
/// Persisted in UserDefaults as a small JSON blob.
final class DailyGoalStore: ObservableObject {
    @Published private(set) var dailyGoal: Int = 20
    @Published private(set) var activityByDay: [String: Int] = [:]   // "yyyy-MM-dd" → count
    @Published private(set) var totalReviews: Int = 0

    private let goalKey = "kana-study.daily.goal"
    private let activityKey = "kana-study.daily.activity.v1"
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
        if let data = defaults.data(forKey: activityKey),
           let decoded = try? JSONDecoder().decode([String: Int].self, from: data) {
            activityByDay = decoded
            totalReviews = decoded.values.reduce(0, +)
        }
    }

    private func save() {
        defaults.set(dailyGoal, forKey: goalKey)
        if let encoded = try? JSONEncoder().encode(activityByDay) {
            defaults.set(encoded, forKey: activityKey)
        }
    }
}

struct HeatmapCell: Identifiable, Hashable {
    let date: Date
    let count: Int
    var id: Date { date }
}