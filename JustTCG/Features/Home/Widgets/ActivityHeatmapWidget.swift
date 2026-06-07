import SwiftUI
import SwiftData

struct ActivityHeatmapWidget: View {
    @Query(sort: \Match.date, order: .reverse) private var matches: [Match]

    private let weeks = 16
    private let cellSize: CGFloat = 10
    private let cellSpacing: CGFloat = 2
    private let monthLabelHeight: CGFloat = 14

    private var days: [HeatmapDay] {
        ActivityHeatmapEngine.compute(matches: matches, weeks: weeks)
    }

    private var columns: [[HeatmapDay]] {
        stride(from: 0, to: days.count, by: 7).map { Array(days[$0..<$0 + 7]) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("Activity")
                    .font(.headline)
                Text("last \(weeks) weeks")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .top, spacing: cellSpacing) {
                dayLabels
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: cellSpacing) {
                        ForEach(0..<columns.count, id: \.self) { col in
                            columnView(col)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    // MARK: - Subviews

    private var dayLabels: some View {
        let labels = ["S", "M", "T", "W", "T", "F", "S"]
        return VStack(alignment: .leading, spacing: cellSpacing) {
            Color.clear.frame(width: cellSize, height: monthLabelHeight)
            ForEach(0..<7, id: \.self) { row in
                if [0, 2, 4, 6].contains(row) {
                    Text(labels[row])
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: cellSize, height: cellSize)
                } else {
                    Color.clear.frame(width: cellSize, height: cellSize)
                }
            }
        }
    }

    private func columnView(_ col: Int) -> some View {
        VStack(alignment: .leading, spacing: cellSpacing) {
            if let label = monthLabel(for: col) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: cellSize, height: monthLabelHeight, alignment: .leading)
                    .fixedSize(horizontal: true, vertical: false)
            } else {
                Color.clear.frame(width: cellSize, height: monthLabelHeight)
            }
            ForEach(0..<7, id: \.self) { row in
                cellView(columns[col][row])
            }
        }
    }

    @ViewBuilder
    private func cellView(_ day: HeatmapDay) -> some View {
        let shape = RoundedRectangle(cornerRadius: 2)
        shape
            .fill(cellFill(day))
            .frame(width: cellSize, height: cellSize)
            .overlay {
                if day.isToday {
                    shape.strokeBorder(Color.accentColor, lineWidth: 1)
                }
            }
    }

    // MARK: - Helpers

    private func cellFill(_ day: HeatmapDay) -> Color {
        if day.isFuture { return Color(.systemFill).opacity(0.4) }
        switch day.count {
        case 0:      return Color(.systemFill)
        case 1:      return Color.accentColor.opacity(0.3)
        case 2...3:  return Color.accentColor.opacity(0.65)
        default:     return Color.accentColor
        }
    }

    private func monthLabel(for col: Int) -> String? {
        let cal = Calendar.current
        let sunday = columns[col][0].date
        let month = cal.component(.month, from: sunday)
        if col > 0 {
            let prevMonth = cal.component(.month, from: columns[col - 1][0].date)
            guard month != prevMonth else { return nil }
        }
        return cal.shortMonthSymbols[month - 1]
    }
}
