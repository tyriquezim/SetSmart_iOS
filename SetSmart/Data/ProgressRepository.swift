import Foundation
import Supabase

struct ProgressRepository {
    private let db = SupabaseClientProvider.shared

    // MARK: - Lifts list

    func fetchExerciseSummaries() async throws -> [ExerciseSummary] {
        struct SessionRow: Decodable {
            let id: UUID
            let startedAt: Date
            let workoutSets: [SetRow]

            struct SetRow: Decodable {
                let exerciseId: UUID
                let reps: Int
                let weightKg: FlexDouble?
                let exercise: Exercise?

                enum CodingKeys: String, CodingKey {
                    case exerciseId = "exercise_id"
                    case reps
                    case weightKg   = "weight_kg"
                    case exercise
                }
            }

            enum CodingKeys: String, CodingKey {
                case id
                case startedAt   = "started_at"
                case workoutSets = "workout_sets"
            }
        }

        let sessions: [SessionRow] = try await db
            .from("workout_sessions")
            .select("id,started_at,workout_sets(exercise_id,reps,weight_kg,exercise:exercises(id,owner_id,name,kind,muscle_group,equipment))")
            .order("started_at", ascending: true)
            .execute()
            .value

        guard !sessions.isEmpty else { return [] }

        struct Entry { let sessionId: UUID; let startedAt: Date; let reps: Int; let weightKg: Double? }
        var exerciseMap: [UUID: Exercise] = [:]
        var byExercise:  [UUID: [Entry]]  = [:]

        for session in sessions {
            for s in session.workoutSets {
                guard let ex = s.exercise, !ex.isCardio else { continue }
                exerciseMap[s.exerciseId] = ex
                byExercise[s.exerciseId, default: []].append(
                    Entry(sessionId: session.id, startedAt: session.startedAt,
                          reps: s.reps, weightKg: s.weightKg?.value)
                )
            }
        }

        var result: [ExerciseSummary] = []

        for (exerciseId, entries) in byExercise {
            guard let exercise = exerciseMap[exerciseId] else { continue }

            let weights = entries.compactMap(\.weightKg).filter { $0 > 0 }
            let maxWeight = weights.max()
            let maxReps   = entries.map(\.reps).max() ?? 0
            let isPrimarilyBodyweight = maxWeight == nil

            let bestE1rm = entries.compactMap { e -> Double? in
                guard let w = e.weightKg, w > 0, e.reps > 0 else { return nil }
                return w * (1.0 + Double(e.reps) / 30.0)
            }.max()

            let lastDate = entries.map(\.startedAt).max() ?? .distantPast

            // Best metric per session for sparkline
            var perSession: [UUID: (startedAt: Date, metric: Double)] = [:]
            for e in entries {
                let metric: Double
                if isPrimarilyBodyweight {
                    metric = Double(e.reps)
                } else {
                    guard let w = e.weightKg, w > 0 else { continue }
                    metric = w * (1.0 + Double(e.reps) / 30.0)
                }
                if let existing = perSession[e.sessionId] {
                    if metric > existing.metric { perSession[e.sessionId] = (e.startedAt, metric) }
                } else {
                    perSession[e.sessionId] = (e.startedAt, metric)
                }
            }

            let sparkPoints = perSession.values
                .sorted { $0.startedAt < $1.startedAt }
                .suffix(15)
                .map(\.metric)

            result.append(ExerciseSummary(
                id:                    exerciseId,
                exercise:              exercise,
                lastPerformedAt:       lastDate,
                bestE1rmKg:            bestE1rm,
                maxWeightKg:           maxWeight,
                maxReps:               maxReps,
                isPrimarilyBodyweight: isPrimarilyBodyweight,
                sparklinePoints:       sparkPoints
            ))
        }

        return result.sorted { $0.lastPerformedAt > $1.lastPerformedAt }
    }

    // MARK: - Exercise detail

    func fetchExerciseStats(exerciseId: UUID) async throws -> [ExerciseSessionStats] {
        struct SetRow: Decodable {
            let sessionId: UUID
            let reps: Int
            let weightKg: FlexDouble?
            let session: SessionRef

            struct SessionRef: Decodable {
                let startedAt: Date
                enum CodingKeys: String, CodingKey { case startedAt = "started_at" }
            }

            enum CodingKeys: String, CodingKey {
                case sessionId = "session_id"
                case reps
                case weightKg  = "weight_kg"
                case session
            }
        }

        let rows: [SetRow] = try await db
            .from("workout_sets")
            .select("session_id,reps,weight_kg,session:workout_sessions(started_at)")
            .eq("exercise_id", value: exerciseId.uuidString)
            .execute()
            .value

        struct SessionData { var startedAt: Date; var sets: [(reps: Int, weightKg: Double?)] }
        var sessions: [UUID: SessionData] = [:]
        for row in rows {
            if sessions[row.sessionId] == nil {
                sessions[row.sessionId] = SessionData(startedAt: row.session.startedAt, sets: [])
            }
            sessions[row.sessionId]!.sets.append((reps: row.reps, weightKg: row.weightKg?.value))
        }

        return sessions.map { (sessionId, data) -> ExerciseSessionStats in
            let maxReps      = data.sets.map(\.reps).max() ?? 0
            let maxWeightKg  = data.sets.compactMap(\.weightKg).filter { $0 > 0 }.max()
            let bestE1rm     = data.sets.compactMap { s -> Double? in
                guard let w = s.weightKg, w > 0, s.reps > 0 else { return nil }
                return w * (1.0 + Double(s.reps) / 30.0)
            }.max()
            let volumeKg     = data.sets.reduce(0.0) { $0 + Double($1.reps) * ($1.weightKg ?? 0) }
            let totalReps    = data.sets.map(\.reps).reduce(0, +)

            return ExerciseSessionStats(
                exerciseId:  exerciseId,
                sessionId:   sessionId,
                startedAt:   data.startedAt,
                setCount:    data.sets.count,
                maxReps:     maxReps,
                maxWeightKg: maxWeightKg.map { FlexDouble($0) },
                bestE1rmKg:  bestE1rm.map { FlexDouble($0) },
                volumeKg:    volumeKg > 0 ? FlexDouble(volumeKg) : nil,
                totalReps:   totalReps
            )
        }.sorted { $0.startedAt < $1.startedAt }
    }
}
