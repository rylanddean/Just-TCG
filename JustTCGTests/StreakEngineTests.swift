import Testing
import Foundation
@testable import JustTCG

@Suite("StreakEngine")
struct StreakEngineTests {

    // MARK: - Helpers

    private func makeCalendar() -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private func date(daysAgo: Int, calendar: Calendar) -> Date {
        let today = calendar.startOfDay(for: Date())
        return calendar.date(byAdding: .day, value: -daysAgo, to: today)!
    }

    private func matches(daysAgo: [Int], calendar: Calendar) -> [Match] {
        daysAgo.map { Match(date: date(daysAgo: $0, calendar: calendar), opponentArchetype: "Charizard ex", result: .win) }
    }

    // MARK: - Tests

    @Test func zeroMatches() {
        let result = StreakEngine.compute(matches: [], dailyGoal: 1, calendar: makeCalendar())
        #expect(result.currentStreak == 0)
        #expect(result.todayCount == 0)
        #expect(result.goalMet == false)
    }

    @Test func metGoalTodayOnly() {
        let cal = makeCalendar()
        let result = StreakEngine.compute(matches: matches(daysAgo: [0], calendar: cal), dailyGoal: 1, calendar: cal)
        #expect(result.currentStreak == 1)
        #expect(result.goalMet == true)
    }

    @Test func metGoalYesterdayAndToday() {
        let cal = makeCalendar()
        let result = StreakEngine.compute(matches: matches(daysAgo: [0, 1], calendar: cal), dailyGoal: 1, calendar: cal)
        #expect(result.currentStreak == 2)
        #expect(result.goalMet == true)
    }

    @Test func metGoalYesterdayNotToday() {
        let cal = makeCalendar()
        let result = StreakEngine.compute(matches: matches(daysAgo: [1], calendar: cal), dailyGoal: 1, calendar: cal)
        #expect(result.currentStreak == 1)
        #expect(result.goalMet == false)
    }

    @Test func gapBreaksStreak() {
        // Today and yesterday met but two days ago is empty — streak should only be 2 (today + yesterday)
        // Gap three days ago with matches before it should not add to streak
        let cal = makeCalendar()
        let ms = matches(daysAgo: [0, 1, 3, 4], calendar: cal)
        let result = StreakEngine.compute(matches: ms, dailyGoal: 1, calendar: cal)
        #expect(result.currentStreak == 2)
    }

    @Test func dailyGoalThree() {
        let cal = makeCalendar()
        // 3 today, 2 yesterday (doesn't count), 3 two days ago — only today should count
        var ms = matches(daysAgo: [0, 0, 0], calendar: cal)
        ms += matches(daysAgo: [1, 1], calendar: cal)
        ms += matches(daysAgo: [2, 2, 2], calendar: cal)
        let result = StreakEngine.compute(matches: ms, dailyGoal: 3, calendar: cal)
        #expect(result.currentStreak == 1)
        #expect(result.goalMet == true)
        #expect(result.todayCount == 3)
    }
}
