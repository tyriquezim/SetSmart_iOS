import Foundation
import Supabase

struct WorkoutRepository {
    private let db = SupabaseClientProvider.shared

    // MARK: - Save finished workout

    func logWorkout(state: WorkoutState, notes: String?) async throws {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        struct Payload: Encodable { let p_workout: WorkoutPayload }
        struct WorkoutPayload: Encodable {
            let id: UUID; let routine_id: UUID?; let name: String
            let started_at, finished_at: String; let notes: String?
            let sets: [SetPayload]
        }
        struct SetPayload: Encodable {
            let exercise_id: UUID; let exercise_position, set_number: Int
            let target_reps: Int?; let target_weight_kg: Double?
            let reps: Int; let weight_kg: Double?; let completed_at: String
        }

        let sets = state.performedOrder.enumerated().flatMap { p, exerciseIdx -> [SetPayload] in
            let ex = state.exercises[exerciseIdx]
            return ex.logged.enumerated().map { setIdx, logged in
                SetPayload(
                    exercise_id:       ex.exerciseId,
                    exercise_position: p,
                    set_number:        setIdx + 1,
                    target_reps:       logged.targetReps,
                    target_weight_kg:  logged.targetWeightKg,
                    reps:              logged.reps,
                    weight_kg:         logged.weightKg,
                    completed_at:      iso.string(from: logged.completedAt)
                )
            }
        }

        let payload = Payload(p_workout: WorkoutPayload(
            id:          state.id,
            routine_id:  state.routineId,
            name:        state.name,
            started_at:  iso.string(from: state.startedAt),
            finished_at: iso.string(from: state.finishedAt ?? Date()),
            notes:       notes?.isEmpty == true ? nil : notes,
            sets:        sets
        ))

        try await db.rpc("log_workout", params: payload).execute()
    }

    // MARK: - History list

    func fetchHistory(limit: Int = 20, before: Date? = nil) async throws -> [WorkoutSessionSummary] {
        let base = db
            .from("workout_sessions")
            .select("id,routine_id,name,started_at,finished_at,notes,workout_sets(reps,weight_kg)")
        if let before {
            let iso = ISO8601DateFormatter()
            return try await base
                .lt("started_at", value: iso.string(from: before))
                .order("started_at", ascending: false)
                .limit(limit)
                .execute()
                .value
        }
        return try await base
            .order("started_at", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    // MARK: - Session detail

    func fetchSession(id: UUID) async throws -> WorkoutSession {
        try await db
            .from("workout_sessions")
            .select("id,routine_id,name,started_at,finished_at,notes,workout_sets(*,exercise:exercises(name))")
            .eq("id", value: id.uuidString)
            .single()
            .execute()
            .value
    }

    func deleteSession(id: UUID) async throws {
        try await db
            .from("workout_sessions")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    // MARK: - Workout times for energy estimates

    struct WorkoutTimeSlot: Sendable {
        let startedAt: Date
        let finishedAt: Date?
    }

    /// Fetch start/finish times for all workouts whose local start day equals `localDay` ("yyyy-MM-dd").
    func fetchWorkoutTimes(localDay: String) async throws -> [WorkoutTimeSlot] {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        guard let dayStart  = f.date(from: localDay),
              let dayEnd    = Calendar.current.date(byAdding: .day, value: 1, to: dayStart)
        else { return [] }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        struct Row: Codable, Sendable {
            let startedAt:  Date
            let finishedAt: Date?
            enum CodingKeys: String, CodingKey {
                case startedAt  = "started_at"
                case finishedAt = "finished_at"
            }
        }

        let rows: [Row] = try await db
            .from("workout_sessions")
            .select("id,started_at,finished_at")
            .gte("started_at", value: iso.string(from: dayStart))
            .lt("started_at",  value: iso.string(from: dayEnd))
            .order("started_at")
            .execute()
            .value

        return rows.map { WorkoutTimeSlot(startedAt: $0.startedAt, finishedAt: $0.finishedAt) }
    }

    // MARK: - Load exercise history for workout hints

    func loadExerciseHistory(exerciseIds: [UUID]) async throws -> [UUID: ExerciseHistory] {
        guard !exerciseIds.isEmpty else { return [:] }
        let idStrings = exerciseIds.map { $0.uuidString }

        // Query 1: aggregate stats per exercise
        let stats: [ExerciseSessionStats] = try await db
            .from("exercise_session_stats")
            .select("exercise_id,session_id,started_at,set_count,max_reps,max_weight_kg,best_e1rm_kg,total_reps")
            .in("exercise_id", value: idStrings)
            .order("started_at", ascending: true)
            .execute()
            .value

        // Aggregate per exercise
        var bestE1rm:    [UUID: Double] = [:]
        var maxWeight:   [UUID: Double] = [:]
        var maxReps:     [UUID: Int]    = [:]
        var lastDate:    [UUID: Date]   = [:]
        var lastSession: [UUID: UUID]   = [:]

        for s in stats {
            let eid = s.exerciseId
            if let v = s.bestE1rmKg?.value  { bestE1rm[eid]  = max(bestE1rm[eid]  ?? 0, v) }
            if let v = s.maxWeightKg?.value { maxWeight[eid] = max(maxWeight[eid] ?? 0, v) }
            maxReps[eid]  = max(maxReps[eid]  ?? 0, s.maxReps)
            if lastDate[eid] == nil || s.startedAt > lastDate[eid]! {
                lastDate[eid]    = s.startedAt
                lastSession[eid] = s.sessionId
            }
        }

        guard !lastSession.isEmpty else { return [:] }

        // Query 2: last sets for each exercise's most recent session
        let sessionIds = Array(Set(lastSession.values)).map { $0.uuidString }
        let rows: [HistorySetRow] = try await db
            .from("workout_sets")
            .select("exercise_id,session_id,set_number,reps,weight_kg")
            .in("session_id", value: sessionIds)
            .in("exercise_id", value: idStrings)
            .order("set_number", ascending: true)
            .execute()
            .value

        var lastSetsMap: [UUID: [LastSet]] = [:]
        for row in rows {
            guard let sid = lastSession[row.exerciseId], sid == row.sessionId else { continue }
            let ls = LastSet(setNumber: row.setNumber, reps: row.reps, weightKg: row.weightKg?.value)
            lastSetsMap[row.exerciseId, default: []].append(ls)
        }

        var result: [UUID: ExerciseHistory] = [:]
        for eid in exerciseIds {
            guard maxReps[eid] != nil || bestE1rm[eid] != nil else { continue }
            result[eid] = ExerciseHistory(
                bestE1rmKg:     bestE1rm[eid],
                maxWeightKg:    maxWeight[eid],
                maxReps:        maxReps[eid] ?? 0,
                lastPerformedAt: lastDate[eid],
                lastSets:       lastSetsMap[eid] ?? []
            )
        }
        return result
    }
}
