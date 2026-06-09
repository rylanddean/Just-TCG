import Foundation
import SwiftData
import Observation

@Observable
final class PrepPlanRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchAll() -> [PrepPlan] {
        let descriptor = FetchDescriptor<PrepPlan>(sortBy: [SortDescriptor(\.tournamentDate, order: .forward)])
        return (try? context.fetch(descriptor)) ?? []
    }

    @discardableResult
    func create(name: String, tournamentDate: Date, deckID: UUID?) -> PrepPlan {
        let plan = PrepPlan(name: name, tournamentDate: tournamentDate, deckID: deckID)
        context.insert(plan)
        save()
        return plan
    }

    func delete(_ plan: PrepPlan) {
        context.delete(plan)
        save()
    }

    @discardableResult
    func addGoal(to plan: PrepPlan, archetypeName: String, targetCount: Int) -> MatchupGoal {
        let goal = MatchupGoal(archetypeName: archetypeName, targetSessionCount: targetCount)
        goal.plan = plan
        plan.matchupGoals.append(goal)
        context.insert(goal)
        save()
        return goal
    }

    func removeGoal(_ goal: MatchupGoal) {
        context.delete(goal)
        save()
    }

    @discardableResult
    func logSession(for goal: MatchupGoal, result: MatchResult, notes: String) -> PrepSession {
        let session = PrepSession(result: result, notes: notes)
        session.goal = goal
        goal.sessions.append(session)
        context.insert(session)
        save()
        return session
    }

    func deleteSession(_ session: PrepSession) {
        context.delete(session)
        save()
    }

    private func save() {
        try? context.save()
    }
}
