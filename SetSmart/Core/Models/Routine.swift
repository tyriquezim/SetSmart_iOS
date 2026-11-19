import Foundation

// MARK: - Database models

struct RoutineSummary: Identifiable, Codable, Sendable {
    let id: UUID
    var name: String
    var notes: String?
    var updatedAt: Date
    var routineExercises: [ExerciseCountRow]?

    var exerciseCount: Int { routineExercises?.first?.count ?? 0 }

    struct ExerciseCountRow: Codable, Sendable { let count: Int }

    enum CodingKeys: String, CodingKey {
        case id, name, notes
        case updatedAt        = "updated_at"
        case routineExercises = "routine_exercises"
    }
}

struct Routine: Identifiable, Codable, Sendable {
    let id: UUID
    var name: String
    var notes: String?
    var updatedAt: Date
    var routineExercises: [RoutineExercise]

    enum CodingKeys: String, CodingKey {
        case id, name, notes
        case updatedAt        = "updated_at"
        case routineExercises = "routine_exercises"
    }
}

struct RoutineExercise: Identifiable, Codable, Sendable {
    var exerciseId: UUID
    var position: Int
    var restSeconds: Int
    var sets: [PlannedSet]
    var targetDurationS: Int?    // cardio only: goal duration
    var notes: String?
    var exercise: Exercise?

    var id: Int { position }

    var isCardio: Bool { exercise?.isCardio ?? false }

    enum CodingKeys: String, CodingKey {
        case exerciseId     = "exercise_id"
        case position
        case restSeconds    = "rest_seconds"
        case sets
        case targetDurationS = "target_duration_s"
        case notes
        case exercise
    }
}

struct PlannedSet: Codable, Sendable {
    var reps: Int
    var weightKg: Double?

    enum CodingKeys: String, CodingKey {
        case reps
        case weightKg = "weight_kg"
    }
}

// MARK: - Local editing models

struct EditableRoutine {
    var name: String = ""
    var notes: String = ""
    var exercises: [EditableRoutineExercise] = []

    init() {}

    init(from routine: Routine) {
        name      = routine.name
        notes     = routine.notes ?? ""
        exercises = routine.routineExercises.map { EditableRoutineExercise(from: $0) }
    }
}

struct EditableRoutineExercise: Identifiable {
    let id = UUID()
    var exerciseId: UUID
    var exerciseName: String
    var kind: ExerciseKind
    var cardioActivity: CardioActivity?
    var restSeconds: Int
    var sets: [EditablePlannedSet]
    var targetDurationMin: Int?   // cardio only: goal in whole minutes (nil = no goal)
    var notes: String

    var isCardio: Bool { kind == .cardio }

    init(exercise: Exercise) {
        exerciseId        = exercise.id
        exerciseName      = exercise.name
        kind              = exercise.kind
        cardioActivity    = exercise.cardioActivity
        if exercise.isCardio {
            restSeconds       = 0
            sets              = []
            targetDurationMin = 30
        } else {
            restSeconds       = 90
            sets              = [EditablePlannedSet(), EditablePlannedSet(), EditablePlannedSet()]
            targetDurationMin = nil
        }
        notes = ""
    }

    init(from re: RoutineExercise) {
        exerciseId        = re.exerciseId
        exerciseName      = re.exercise?.name ?? "Exercise"
        kind              = re.exercise?.kind ?? .weights
        cardioActivity    = re.exercise?.cardioActivity
        restSeconds       = re.restSeconds
        sets              = re.sets.map { EditablePlannedSet(reps: $0.reps, weightKg: $0.weightKg) }
        targetDurationMin = re.targetDurationS.map { $0 / 60 }
        notes             = re.notes ?? ""
    }

    var setsDescription: String {
        "\(sets.count) set\(sets.count == 1 ? "" : "s")"
    }
    var restDescription: String { formatRestSeconds(restSeconds) }

    var goalDescription: String {
        guard let min = targetDurationMin, min > 0 else { return "No goal" }
        if min >= 60 {
            let h = min / 60
            let m = min % 60
            return m == 0 ? "\(h) h" : "\(h) h \(m) min"
        }
        return "\(min) min"
    }
}

struct EditablePlannedSet: Identifiable {
    let id = UUID()
    var reps: Int = 10
    var weightKg: Double? = nil

    init(reps: Int = 10, weightKg: Double? = nil) {
        self.reps     = reps
        self.weightKg = weightKg
    }
}

// MARK: - Helpers

let restPresets: [Int] = [0, 30, 45, 60, 75, 90, 120, 150, 180, 240, 300]

func formatRestSeconds(_ seconds: Int) -> String {
    if seconds == 0  { return "No rest" }
    if seconds < 60  { return "\(seconds) s" }
    let mins = seconds / 60
    let secs = seconds % 60
    return secs == 0 ? "\(mins) min" : "\(mins):\(String(format: "%02d", secs)) min"
}
