import SwiftUI
import Charts

struct WeeklyRecord: Identifiable {
    let id = UUID()
    let weekStart: Date
    let wins: Int
    let losses: Int
    let ties: Int

    var total: Int { wins + losses + ties }
    var winRate: Double {
        guard total > 0 else { return 0 }
        return Double(wins) / Double(total) * 100
    }
}

struct WinRateChartView: View {
    let records: [WeeklyRecord]

    @State private var selectedWeek: WeeklyRecord? = nil

    var body: some View {
        if records.count < 5 {
            ContentUnavailableView(
                "Not Enough Data",
                systemImage: "chart.line.uptrend.xyaxis",
                description: Text("Log more matches to see your win rate trend.")
            )
            .frame(height: 200)
        } else {
            chart
        }
    }

    private var chart: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let sel = selectedWeek {
                tooltipLabel(sel)
            }
            Chart {
                // 50 % reference line
                RuleMark(y: .value("50%", 50))
                    .foregroundStyle(Color.secondary.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .annotation(position: .trailing, alignment: .leading) {
                        Text("50%")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                ForEach(records) { rec in
                    LineMark(
                        x: .value("Week", rec.weekStart, unit: .weekOfYear),
                        y: .value("Win %", rec.winRate)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Color.accentColor)

                    AreaMark(
                        x: .value("Week", rec.weekStart, unit: .weekOfYear),
                        y: .value("Win %", rec.winRate)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.25), Color.accentColor.opacity(0)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )

                    if let sel = selectedWeek, sel.id == rec.id {
                        PointMark(
                            x: .value("Week", rec.weekStart, unit: .weekOfYear),
                            y: .value("Win %", rec.winRate)
                        )
                        .foregroundStyle(Color.accentColor)
                        .symbolSize(80)
                    }
                }
            }
            .chartYScale(domain: 0...100)
            .chartYAxis {
                AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let v = value.as(Int.self) {
                            Text("\(v)%")
                                .font(.caption2)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .weekOfYear)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { val in
                                    let origin = geo[proxy.plotFrame!].origin
                                    let location = CGPoint(
                                        x: val.location.x - origin.x,
                                        y: val.location.y - origin.y
                                    )
                                    if let date: Date = proxy.value(atX: location.x) {
                                        selectedWeek = closestRecord(to: date)
                                    }
                                }
                                .onEnded { _ in selectedWeek = nil }
                        )
                }
            }
            .frame(height: 180)
        }
    }

    private func tooltipLabel(_ rec: WeeklyRecord) -> some View {
        let wk = rec.weekStart.formatted(.dateTime.month(.abbreviated).day())
        return Text("\(wk) · \(rec.wins)W \(rec.losses)L \(rec.ties)T — \(String(format: "%.0f%%", rec.winRate))")
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
    }

    private func closestRecord(to date: Date) -> WeeklyRecord? {
        records.min(by: {
            abs($0.weekStart.timeIntervalSince(date)) < abs($1.weekStart.timeIntervalSince(date))
        })
    }
}
