import Foundation

// MARK: - History list

struct WorkoutSessionSummary: Identifiable, Codable, Sendable {
    let id: UUID
    var routineId: UUID?
    var name: String
    var startedAt: Date
    var finishedAt: Date?
    var notes: String?
    var workoutSets: [SummarySets]

    var duration: TimeInterval { (finishedAt ?? startedAt).timeIntervalSince(startedAt) }
    var setCount:  Int         { workoutSets.count }
    var volumeKg:  Double      { workoutSets.reduce(0) { $0 + Double($1.reps) * ($1.weightKg?.value ?? 0) } }

    struct SummarySets: Codable, Sendable {
        let reps: Int
        let weightKg: FlexDouble?
        enum CodingKeys: String, CodingKey { case reps; case weightKg = "weight_kg" }
    }

    enum CodingKeys: String, CodingKey {
        case id, name, notes
        case routineId   = "routine_id"
        case startedAt   = "started_at"
        case finishedAt  = "finished_at"
        case workoutSets = "workout_sets"
    }
}

// MARK: - Session detail

struct WorkoutSession: Identifiable, Codable, Sendable {
    let id: UUID
    var routineId: UUID?
    var name: String
    var startedAt: Date
    var finishedAt: Date?
    var notes: String?
    var workoutSets: [SessionSet]

    enum CodingKeys: String, CodingKey {
        case id, name, notes
        case routineId   = "routine_id"
        case startedAt   = "started_at"
        case finishedAt  = "finished_at"
        case workoutSets = "workout_sets"
    }
}

struct SessionSet: Codable, Sendable {
    var exerciseId: UUID?
    var exercisePosition: Int
    var setNumber: Int
    var targetReps: Int?
    var targetWeightKg: FlexDouble?
    var reps: Int
    var weightKg: FlexDouble?
    var completedAt: Date
    var exercise: ExerciseName?

    struct ExerciseName: Codable, Sendable { var name: String }

    enum CodingKeys: String, CodingKey {
        case exerciseId       = "exercise_id"
        case exercisePosition = "exercise_position"
        case setNumber        = "set_number"
        case targetReps       = "target_reps"
        case targetWeightKg   = "target_weight_kg"
        case reps
        case weightKg         = "weight_kg"
        case completedAt      = "completed_at"
        case exercise
    }
}

// MARK: - Exercise history (fetched from exercise_session_stats)

struct ExerciseSessionStats: Codable, Sendable {
    var exerciseId: UUID
    var sessionId: UUID
    var startedAt: Date
    var setCount: Int
    var maxReps: Int
    var maxWeightKg: FlexDouble?
    var bestE1rmKg: FlexDouble?
    var volumeKg: FlexDouble?
    var totalReps: Int

    enum CodingKeys: String, CodingKey {
        case exerciseId  = "exercise_id"
        case sessionId   = "session_id"
        case startedAt   = "started_at"
        case setCount    = "set_count"
        case maxReps     = "max_reps"
        case maxWeightKg = "max_weight_kg"
        case bestE1rmKg  = "best_e1rm_kg"
        case volumeKg    = "volume_kg"
        case totalReps   = "total_reps"
    }
}

struct HistorySetRow: Codable, Sendable {
    var exerciseId: UUID
    var sessionId: UUID
    var setNumber: Int
    var reps: Int
    var weightKg: FlexDouble?

    enum CodingKeys: String, CodingKey {
        case exerciseId = "exercise_id"
        case sessionId  = "session_id"
        case setNumber  = "set_number"
        case reps
        case weightKg   = "weight_kg"
    }
}
