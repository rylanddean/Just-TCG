import SwiftUI
import SwiftData

struct StreakWidget: View {
    @Query(sort: \Match.date, order: .reverse) private var matches: [Match]
    @AppStorage("streak_daily_goal") private var dailyGoal: Int = 1

    private var result: StreakResult {
        StreakEngine.compute(matches: matches, dailyGoal: dailyGoal)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(result.goalMet ? .orange : .secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(result.currentStreak)")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                    Text("day streak")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if result.goalMet {
                    Text("Goal met today ✓")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.green)
                } else {
                    Text("\(result.todayCount) / \(dailyGoal) games today")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .background(.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
}
