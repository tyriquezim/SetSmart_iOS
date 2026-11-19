import Foundation
import Supabase

private let cardioEmbed = "workout_cardio(*,exercise:exercises(name,cardio_activity,cardio_met))"

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
            let sets: [SetPayload]; let cardio: [CardioPayload]
        }
        struct SetPayload: Encodable {
            let exercise_id: UUID; let exercise_position, set_number: Int
            let target_reps: Int?; let target_weight_kg: Double?
            let reps: Int; let weight_kg: Double?; let completed_at: String
        }
        struct CardioPayload: Encodable {
            let exercise_id: UUID; let exercise_position: Int
            let target_duration_s: Int?
            let started_at: String; let duration_s: Int
            let distance_m: Double?; let effort: String?

            func encode(to encoder: any Encoder) throws {
                var c = encoder.container(keyedBy: CodingKeys.self)
                try c.encode(exercise_id,       forKey: .exercise_id)
                try c.encode(exercise_position, forKey: .exercise_position)
                try c.encode(target_duration_s, forKey: .target_duration_s)
                try c.encode(started_at,        forKey: .started_at)
                try c.encode(duration_s,        forKey: .duration_s)
                try c.encode(distance_m,        forKey: .distance_m)
                try c.encode(effort,            forKey: .effort)
            }
            enum CodingKeys: String, CodingKey {
                case exercise_id, exercise_position, target_duration_s
                case started_at, duration_s, distance_m, effort
            }
        }

        let sets = state.performedOrder.enumerated().flatMap { p, exerciseIdx -> [SetPayload] in
            let ex = state.exercises[exerciseIdx]
            guard !ex.isCardio else { return [] }
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

        let cardio = state.performedOrder.enumerated().compactMap { p, exerciseIdx -> CardioPayload? in
            let ex = state.exercises[exerciseIdx]
            guard ex.isCardio, let log = ex.cardioLog else { return nil }
            return CardioPayload(
                exercise_id:       ex.exerciseId,
                exercise_position: p,
                target_duration_s: ex.cardio?.targetDurationS,
                started_at:        iso.string(from: log.startedAt),
                duration_s:        log.durationS,
                distance_m:        log.distanceM,
                effort:            log.effort?.rawValue
            )
        }

        let payload = Payload(p_workout: WorkoutPayload(
            id:          state.id,
            routine_id:  state.routineId,
            name:        state.name,
            started_at:  iso.string(from: state.startedAt),
            finished_at: iso.string(from: state.finishedAt ?? Date()),
            notes:       notes?.isEmpty == true ? nil : notes,
            sets:        sets,
            cardio:      cardio
        ))

        try await db.rpc("log_workout", params: payload).execute()
    }

    // MARK: - History list

    func fetchHistory(limit: Int = 20, before: Date? = nil) async throws -> [WorkoutSessionSummary] {
        let selectStr = "id,routine_id,name,started_at,finished_at,notes,workout_sets(reps,weight_kg),\(cardioEmbed)"
        let base = db
            .from("workout_sessions")
            .select(selectStr)
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
        let selectStr = "id,routine_id,name,started_at,finished_at,notes,workout_sets(*,exercise:exercises(name)),\(cardioEmbed)"
        return try await db
            .from("workout_sessions")
            .select(selectStr)
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

    // MARK: - Workout slots for energy estimates

    /// Fetch WorkoutSlots (with embedded cardio) for all workouts whose local start day equals `localDay`.
    func fetchWorkoutSlots(localDay: String) async throws -> [WorkoutSlot] {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        guard let dayStart = f.date(from: localDay),
              let dayEnd   = Calendar.current.date(byAdding: .day, value: 1, to: dayStart)
        else { return [] }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        struct SlotRow: Codable, Sendable {
            let startedAt:  Date
            let finishedAt: Date?
            let workoutSets: [MinSet]
            let workoutCardio: [WorkoutCardioRow]
            struct MinSet: Codable, Sendable { let reps: Int }
            enum CodingKeys: String, CodingKey {
                case startedAt    = "started_at"
                case finishedAt   = "finished_at"
                case workoutSets  = "workout_sets"
                case workoutCardio = "workout_cardio"
            }
        }

        let selectStr = "started_at,finished_at,workout_sets(reps),\(cardioEmbed)"
        let rows: [SlotRow] = try await db
            .from("workout_sessions")
            .select(selectStr)
            .gte("started_at", value: iso.string(from: dayStart))
            .lt("started_at",  value: iso.string(from: dayEnd))
            .order("started_at")
            .execute()
            .value

        return rows.map {
            WorkoutSlot(startedAt: $0.startedAt, finishedAt: $0.finishedAt,
                        setCount: $0.workoutSets.count, cardio: $0.workoutCardio)
        }
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
                bestE1rmKg:      bestE1rm[eid],
                maxWeightKg:     maxWeight[eid],
                maxReps:         maxReps[eid] ?? 0,
                lastPerformedAt: lastDate[eid],
                lastSets:        lastSetsMap[eid] ?? []
            )
        }
        return result
    }
}
