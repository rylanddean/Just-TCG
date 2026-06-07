import Foundation

struct StreakResult {
    let currentStreak: Int
    let todayCount: Int
    let goalMet: Bool
}

enum StreakEngine {
    static func compute(
        matches: [Match],
        dailyGoal: Int,
        calendar: Calendar = .current
    ) -> StreakResult {
        let today = calendar.startOfDay(for: Date())
        let todayCount = matches.filter { calendar.isDate($0.date, inSameDayAs: today) }.count
        let goalMet = todayCount >= dailyGoal

        var streak = 0
        var checkDay = goalMet ? today : calendar.date(byAdding: .day, value: -1, to: today)!

        while true {
            let count = matches.filter { calendar.isDate($0.date, inSameDayAs: checkDay) }.count
            guard count >= dailyGoal else { break }
            streak += 1
            checkDay = calendar.date(byAdding: .day, value: -1, to: checkDay)!
        }

        return StreakResult(currentStreak: streak, todayCount: todayCount, goalMet: goalMet)
    }
}
