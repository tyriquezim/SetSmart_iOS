import Foundation

// MARK: - workout_cardio embedded row

struct WorkoutCardioRow: Codable, Sendable {
    var exerciseId: UUID
    var exercisePosition: Int
    var targetDurationS: Int?
    var startedAt: Date
    var durationS: Int
    var distanceM: Double?
    var effort: CardioEffort?
    var exercise: CardioExerciseRef?

    struct CardioExerciseRef: Codable, Sendable {
        var name: String
        var cardioActivity: CardioActivity?
        var cardioMet: Double?

        enum CodingKeys: String, CodingKey {
            case name
            case cardioActivity = "cardio_activity"
            case cardioMet      = "cardio_met"
        }
    }

    var activity: CardioActivity { exercise?.cardioActivity ?? .other }
    var customMet: Double?       { exercise?.cardioMet }

    var durationText: String { formatCardioTime(durationS) }

    var goalReached: Bool {
        guard let goal = targetDurationS else { return false }
        return durationS >= goal
    }

    var goalText: String? {
        guard let goal = targetDurationS, goal > 0 else { return nil }
        return "Goal \(formatCardioTime(goal))"
    }

    enum CodingKeys: String, CodingKey {
        case exerciseId       = "exercise_id"
        case exercisePosition = "exercise_position"
        case targetDurationS  = "target_duration_s"
        case startedAt        = "started_at"
        case durationS        = "duration_s"
        case distanceM        = "distance_m"
        case effort
        case exercise
    }
}

func formatCardioTime(_ totalSeconds: Int) -> String {
    let h = totalSeconds / 3600
    let m = (totalSeconds % 3600) / 60
    let s = totalSeconds % 60
    if h > 0 { return m > 0 ? "\(h) h \(m) min" : "\(h) h" }
    if s > 0 { return "\(m) min \(s) s" }
    return "\(m) min"
}

// MARK: - Workout slot for energy estimates

struct WorkoutSlot: Sendable {
    let startedAt: Date
    let finishedAt: Date?
    let setCount: Int
    let cardio: [WorkoutCardioRow]
}

// MARK: - History list

struct WorkoutSessionSummary: Identifiable, Codable, Sendable {
    let id: UUID
    var routineId: UUID?
    var name: String
    var startedAt: Date
    var finishedAt: Date?
    var notes: String?
    var workoutSets: [SummarySets]
    var workoutCardio: [WorkoutCardioRow]

    var duration: TimeInterval { (finishedAt ?? startedAt).timeIntervalSince(startedAt) }
    var setCount:  Int         { workoutSets.count }
    var volumeKg:  Double      { workoutSets.reduce(0) { $0 + Double($1.reps) * ($1.weightKg?.value ?? 0) } }

    var asSlot: WorkoutSlot {
        WorkoutSlot(startedAt: startedAt, finishedAt: finishedAt,
                    setCount: setCount, cardio: workoutCardio)
    }

    struct SummarySets: Codable, Sendable {
        let reps: Int
        let weightKg: FlexDouble?
        enum CodingKeys: String, CodingKey { case reps; case weightKg = "weight_kg" }
    }

    enum CodingKeys: String, CodingKey {
        case id, name, notes
        case routineId    = "routine_id"
        case startedAt    = "started_at"
        case finishedAt   = "finished_at"
        case workoutSets  = "workout_sets"
        case workoutCardio = "workout_cardio"
    }
}

extension WorkoutSessionSummary: Hashable {
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
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
    var workoutCardio: [WorkoutCardioRow]

    enum CodingKeys: String, CodingKey {
        case id, name, notes
        case routineId     = "routine_id"
        case startedAt     = "started_at"
        case finishedAt    = "finished_at"
        case workoutSets   = "workout_sets"
        case workoutCardio = "workout_cardio"
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
