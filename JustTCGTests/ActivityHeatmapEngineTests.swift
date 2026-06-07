import Testing
import Foundation
@testable import JustTCG

@Suite("ActivityHeatmapEngine")
struct ActivityHeatmapEngineTests {

    private func makeCalendar() -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private func matchOnDay(daysFromToday: Int, cal: Calendar) -> Match {
        let today = cal.startOfDay(for: Date())
        let date = cal.date(byAdding: .day, value: daysFromToday, to: today)!
        return Match(date: date, opponentArchetype: "Test", result: .win)
    }

    @Test func emptyMatchesAllZeroCount() {
        let cal = makeCalendar()
        let days = ActivityHeatmapEngine.compute(matches: [], weeks: 4, calendar: cal)
        #expect(days.allSatisfy { $0.count == 0 })
        #expect(days.count == 4 * 7)
    }

    @Test func todayCountAndIsToday() {
        let cal = makeCalendar()
        let matches = [matchOnDay(daysFromToday: 0, cal: cal), matchOnDay(daysFromToday: 0, cal: cal)]
        let days = ActivityHeatmapEngine.compute(matches: matches, weeks: 4, calendar: cal)
        let todayDay = days.first(where: { $0.isToday })
        #expect(todayDay != nil)
        #expect(todayDay?.count == 2)
        #expect(todayDay?.isFuture == false)
    }

    @Test func matchesOlderThanWindowExcluded() {
        let cal = makeCalendar()
        // A match exactly one day before the window starts should not appear
        let windowDays = 4 * 7  // 28 days
        // start is Sunday; end is Saturday on or after today
        // Window covers 28 days ending on nearest Saturday
        // A match 29+ days before today's aligned Saturday should be excluded
        let oldMatch = matchOnDay(daysFromToday: -(windowDays + 5), cal: cal)
        let days = ActivityHeatmapEngine.compute(matches: [oldMatch], weeks: 4, calendar: cal)
        #expect(days.allSatisfy { $0.count == 0 })
    }

    @Test func isFutureCorrectness() {
        let cal = makeCalendar()
        let days = ActivityHeatmapEngine.compute(matches: [], weeks: 4, calendar: cal)
        let todayDay = days.first(where: { $0.isToday })
        #expect(todayDay?.isFuture == false)

        // Yesterday should not be future
        let today = cal.startOfDay(for: Date())
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        let yesterdayDay = days.first(where: { cal.isDate($0.date, inSameDayAs: yesterday) })
        #expect(yesterdayDay?.isFuture == false)
        #expect(yesterdayDay?.isToday == false)

        // Any day strictly after today (and within the grid) should be future
        let futureDays = days.filter { $0.isFuture }
        #expect(futureDays.allSatisfy { $0.count == 0 })
    }

    @Test func gridStartsSundayEndsSaturday() {
        let cal = makeCalendar()
        let days = ActivityHeatmapEngine.compute(matches: [], weeks: 8, calendar: cal)
        #expect(days.count == 8 * 7)
        let startWeekday = cal.component(.weekday, from: days.first!.date)  // Sun = 1
        let endWeekday = cal.component(.weekday, from: days.last!.date)    // Sat = 7
        #expect(startWeekday == 1)
        #expect(endWeekday == 7)
    }
}
