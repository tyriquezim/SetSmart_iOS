import Foundation
import Supabase

struct ProgressRepository {
    private let db = SupabaseClientProvider.shared

    // MARK: - Lifts list

    /// All exercises that have been logged, with aggregated stats for the lifts list.
    func fetchExerciseSummaries() async throws -> [ExerciseSummary] {
        // 1. Fetch all session stats ordered oldest-first
        let stats: [ExerciseSessionStats] = try await db
            .from("exercise_session_stats")
            .select("exercise_id,session_id,started_at,set_count,max_reps,max_weight_kg,best_e1rm_kg,volume_kg,total_reps")
            .order("started_at", ascending: true)
            .execute()
            .value

        guard !stats.isEmpty else { return [] }

        // 2. Group by exercise ID
        var grouped: [UUID: [ExerciseSessionStats]] = [:]
        for s in stats { grouped[s.exerciseId, default: []].append(s) }

        // 3. Fetch exercise names for all logged exercise IDs
        let idStrings = Array(grouped.keys).map { $0.uuidString }
        let exercises: [Exercise] = try await db
            .from("exercises")
            .select("id,name,muscle_group,equipment")
            .in("id", value: idStrings)
            .execute()
            .value
        let exerciseMap = Dictionary(exercises.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })

        // 4. Build summaries
        var result: [ExerciseSummary] = []
        for (exerciseId, sessions) in grouped {
            guard let exercise = exerciseMap[exerciseId] else { continue }

            let bestE1rm   = sessions.compactMap { $0.bestE1rmKg?.value }.max()
            let maxWeight  = sessions.compactMap { $0.maxWeightKg?.value }.filter { $0 > 0 }.max()
            let isPrimarilyBodyweight = maxWeight == nil
            let maxReps    = sessions.map { $0.maxReps }.max() ?? 0
            let lastDate   = sessions.map { $0.startedAt }.max() ?? .distantPast

            let sparkPoints: [Double] = sessions.suffix(15).compactMap { s in
                isPrimarilyBodyweight ? Double(s.maxReps) : (s.bestE1rmKg?.value)
            }

            result.append(ExerciseSummary(
                id:                   exerciseId,
                exercise:             exercise,
                lastPerformedAt:      lastDate,
                bestE1rmKg:           bestE1rm,
                maxWeightKg:          maxWeight,
                maxReps:              maxReps,
                isPrimarilyBodyweight: isPrimarilyBodyweight,
                sparklinePoints:      sparkPoints
            ))
        }

        return result.sorted { $0.lastPerformedAt > $1.lastPerformedAt }
    }

    // MARK: - Exercise detail

    func fetchExerciseStats(exerciseId: UUID) async throws -> [ExerciseSessionStats] {
        try await db
            .from("exercise_session_stats")
            .select("exercise_id,session_id,started_at,set_count,max_reps,max_weight_kg,best_e1rm_kg,volume_kg,total_reps")
            .eq("exercise_id", value: exerciseId.uuidString)
            .order("started_at", ascending: true)
            .execute()
            .value
    }
}
