import Foundation

struct HeatmapDay: Equatable {
    let date: Date
    let count: Int
    let isFuture: Bool
    let isToday: Bool
}

enum ActivityHeatmapEngine {
    static func compute(
        matches: [Match],
        weeks: Int = 16,
        calendar: Calendar = .current
    ) -> [HeatmapDay] {
        let today = calendar.startOfDay(for: Date())

        // endDate: nearest Saturday on or after today (Sun=1...Sat=7)
        let weekday = calendar.component(.weekday, from: today)
        let daysToSaturday = (7 - weekday) % 7
        let endDate = calendar.date(byAdding: .day, value: daysToSaturday, to: today)!

        // startDate: Saturday minus (weeks×7 − 1) days = always lands on Sunday
        let startDate = calendar.date(byAdding: .day, value: -(weeks * 7 - 1), to: endDate)!

        var countMap: [Date: Int] = [:]
        for match in matches {
            let day = calendar.startOfDay(for: match.date)
            guard day >= startDate, day <= today else { continue }
            countMap[day, default: 0] += 1
        }

        return (0..<(weeks * 7)).map { i in
            let date = calendar.date(byAdding: .day, value: i, to: startDate)!
            let isToday = calendar.isDate(date, inSameDayAs: today)
            let isFuture = date > today
            return HeatmapDay(
                date: date,
                count: isFuture ? 0 : (countMap[date] ?? 0),
                isFuture: isFuture,
                isToday: isToday
            )
        }
    }
}
