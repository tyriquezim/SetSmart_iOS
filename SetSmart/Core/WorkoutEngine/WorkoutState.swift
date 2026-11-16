import Foundation

// MARK: - Main state

struct WorkoutState: Codable, Sendable {
    var version: Int = 1
    var id: UUID                   // also the log_workout id (idempotent save)
    var routineId: UUID?
    var name: String
    var startedAt: Date
    var finishedAt: Date?
    var exercises: [WorkoutExercise]
    var queue: [Int]               // indices into exercises; queue[0] = current
    var performedOrder: [Int]      // first-performed order → exercise_position in payload
    var phase: Phase

    // MARK: Create from a Routine
    static func create(from routine: Routine, now: Date) -> WorkoutState {
        let valid = routine.routineExercises
            .filter { !$0.sets.isEmpty }
            .sorted { $0.position < $1.position }

        let exercises = valid.map { re in
            WorkoutExercise(
                exerciseId:  re.exerciseId,
                name:        re.exercise?.name ?? "Exercise",
                restSeconds: re.restSeconds,
                sets:        re.sets,
                logged:      [],
                status:      .pending,
                history:     nil
            )
        }

        let queue = Array(exercises.indices)
        let isEmpty = exercises.isEmpty
        return WorkoutState(
            id:             UUID(),
            routineId:      routine.id,
            name:           routine.name,
            startedAt:      now,
            finishedAt:     isEmpty ? now : nil,
            exercises:      exercises,
            queue:          queue,
            performedOrder: [],
            phase:          isEmpty ? .complete : .set
        )
    }
}

// MARK: - Per-exercise state

struct WorkoutExercise: Codable, Sendable {
    var exerciseId: UUID
    var name: String
    var restSeconds: Int
    var sets: [PlannedSet]         // planned (target) sets; can grow via addSet
    var logged: [LoggedSet]
    var status: ExerciseStatus
    var history: ExerciseHistory?
}

enum ExerciseStatus: String, Codable, Sendable {
    case pending, done, skipped
}

// MARK: - Set types

struct LoggedSet: Codable, Sendable {
    var reps: Int
    var weightKg: Double?
    var targetReps: Int?
    var targetWeightKg: Double?
    var completedAt: Date
}

// MARK: - History (loaded after workout starts; never blocks)

struct ExerciseHistory: Codable, Sendable {
    var bestE1rmKg: Double?
    var maxWeightKg: Double?
    var maxReps: Int
    var lastPerformedAt: Date?
    var lastSets: [LastSet]        // sets from the most recent session
}

struct LastSet: Codable, Sendable {
    var setNumber: Int
    var reps: Int
    var weightKg: Double?
}

// MARK: - Phase

enum Phase: Codable, Equatable, Sendable {
    case set
    case rest(startedAt: Date, endsAt: Date)
    case complete

    private enum Tag: String, Codable { case set, rest, complete }
    private enum CK: String, CodingKey { case tag, startedAt, endsAt }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CK.self)
        switch self {
        case .set:
            try c.encode(Tag.set, forKey: .tag)
        case .rest(let s, let e):
            try c.encode(Tag.rest, forKey: .tag)
            try c.encode(s, forKey: .startedAt)
            try c.encode(e, forKey: .endsAt)
        case .complete:
            try c.encode(Tag.complete, forKey: .tag)
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CK.self)
        switch try c.decode(Tag.self, forKey: .tag) {
        case .set:      self = .set
        case .rest:
            self = .rest(
                startedAt: try c.decode(Date.self, forKey: .startedAt),
                endsAt:    try c.decode(Date.self, forKey: .endsAt)
            )
        case .complete: self = .complete
        }
    }
}

// MARK: - Actions

enum WorkoutAction {
    case logSet(reps: Int, weightKg: Double?)
    case endRest
    case adjustRest(deltaSeconds: Int)
    case postpone(PostponeMode)
    case skipExercise
    case addSet
    case editLoggedSet(exerciseIndex: Int, setIndex: Int, reps: Int, weightKg: Double?)
    case finish
    case reopen
}

enum PostponeMode { case next, end }

// MARK: - Selectors output types

struct CurrentSetInfo {
    var exerciseName: String
    var setNumber: Int
    var totalSets: Int
    var targetReps: Int
    var targetWeightKg: Double?
    var previousReps: Int?
    var previousWeightKg: Double?
    var lastTimeReps: Int?
    var lastTimeWeightKg: Double?
    var prefillReps: Int
    var prefillWeightKg: Double?
}

struct WorkoutTotals {
    var setsLogged: Int
    var setsPlanned: Int
    var volumeKg: Double
    var exercisesDone: Int
}

struct PRResult {
    var e1rmPR: Bool
    var weightPR: Bool
}
