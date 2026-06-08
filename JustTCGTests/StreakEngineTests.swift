import XCTest
@testable import JustTCG

final class StreakEngineTests: XCTestCase {

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

    func testZeroMatches() {
        let result = StreakEngine.compute(matches: [], dailyGoal: 1, calendar: makeCalendar())
        XCTAssertEqual(result.currentStreak, 0)
        XCTAssertEqual(result.todayCount, 0)
        XCTAssertFalse(result.goalMet)
    }

    func testMetGoalTodayOnly() {
        let cal = makeCalendar()
        let result = StreakEngine.compute(matches: matches(daysAgo: [0], calendar: cal), dailyGoal: 1, calendar: cal)
        XCTAssertEqual(result.currentStreak, 1)
        XCTAssertTrue(result.goalMet)
    }

    func testMetGoalYesterdayAndToday() {
        let cal = makeCalendar()
        let result = StreakEngine.compute(matches: matches(daysAgo: [0, 1], calendar: cal), dailyGoal: 1, calendar: cal)
        XCTAssertEqual(result.currentStreak, 2)
        XCTAssertTrue(result.goalMet)
    }

    func testMetGoalYesterdayNotToday() {
        let cal = makeCalendar()
        let result = StreakEngine.compute(matches: matches(daysAgo: [1], calendar: cal), dailyGoal: 1, calendar: cal)
        XCTAssertEqual(result.currentStreak, 1)
        XCTAssertFalse(result.goalMet)
    }

    func testGapBreaksStreak() {
        let cal = makeCalendar()
        let ms = matches(daysAgo: [0, 1, 3, 4], calendar: cal)
        let result = StreakEngine.compute(matches: ms, dailyGoal: 1, calendar: cal)
        XCTAssertEqual(result.currentStreak, 2)
    }

    func testDailyGoalThree() {
        let cal = makeCalendar()
        var ms = matches(daysAgo: [0, 0, 0], calendar: cal)
        ms += matches(daysAgo: [1, 1], calendar: cal)
        ms += matches(daysAgo: [2, 2, 2], calendar: cal)
        let result = StreakEngine.compute(matches: ms, dailyGoal: 3, calendar: cal)
        XCTAssertEqual(result.currentStreak, 1)
        XCTAssertTrue(result.goalMet)
        XCTAssertEqual(result.todayCount, 3)
    }
}
