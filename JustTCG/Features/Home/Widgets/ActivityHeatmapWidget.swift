import SwiftUI
import SwiftData

struct ActivityHeatmapWidget: View {
    @Query(sort: \Match.date, order: .reverse) private var matches: [Match]

    private let weeks = 20
    private let cellSpacing: CGFloat = 2
    private let labelColumnWidth: CGFloat = 12

    @State private var cellSize: CGFloat = 0

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

            // Zero-height width probe: fills the card width and drives cellSize.
            Color.clear
                .frame(height: 0)
                .background(
                    GeometryReader { proxy in
                        Color.clear.task { cellSize = computedCellSize(for: proxy.size.width) }
                    }
                )

            if cellSize > 0 {
                HStack(alignment: .top, spacing: cellSpacing) {
                    dayLabels
                    ForEach(0..<columns.count, id: \.self) { col in
                        columnView(col)
                    }
                }

                legendView
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    // MARK: - Layout

    private func computedCellSize(for width: CGFloat) -> CGFloat {
        max(4, (width - labelColumnWidth - CGFloat(weeks) * cellSpacing) / CGFloat(weeks))
    }

    // MARK: - Day labels (S M T W T F S, alternating rows visible)

    private var dayLabels: some View {
        let labels = ["S", "M", "T", "W", "T", "F", "S"]
        return VStack(alignment: .trailing, spacing: cellSpacing) {
            ForEach(0..<7, id: \.self) { row in
                if row.isMultiple(of: 2) {
                    Text(labels[row])
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                        .frame(width: labelColumnWidth, height: cellSize)
                } else {
                    Color.clear.frame(width: labelColumnWidth, height: cellSize)
                }
            }
        }
    }

    // MARK: - Column (no month labels)

    private func columnView(_ col: Int) -> some View {
        VStack(alignment: .leading, spacing: cellSpacing) {
            ForEach(0..<7, id: \.self) { row in
                cellView(columns[col][row])
            }
        }
    }

    // MARK: - Cell

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

    private func cellFill(_ day: HeatmapDay) -> Color {
        if day.isFuture { return .clear }
        switch day.count {
        case 0:    return Color(.systemFill)
        case 1:    return Color.accentColor.opacity(0.25)
        case 2:    return Color.accentColor.opacity(0.5)
        case 3:    return Color.accentColor.opacity(0.75)
        default:   return Color.accentColor
        }
    }

    // MARK: - Legend

    private var legendView: some View {
        HStack(spacing: 4) {
            Text("Less")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
            ForEach(0..<5, id: \.self) { step in
                RoundedRectangle(cornerRadius: 2)
                    .fill(legendSwatch(step: step))
                    .frame(width: cellSize, height: cellSize)
            }
            Text("More")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
    }

    private func legendSwatch(step: Int) -> Color {
        switch step {
        case 0:    return Color(.systemFill)
        case 1:    return Color.accentColor.opacity(0.25)
        case 2:    return Color.accentColor.opacity(0.5)
        case 3:    return Color.accentColor.opacity(0.75)
        default:   return Color.accentColor
        }
    }
}
