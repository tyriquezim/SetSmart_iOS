import Foundation

enum ExerciseKind: String, Codable, CaseIterable, Sendable {
    case weights = "weights"
    case cardio  = "cardio"
}

struct Exercise: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let ownerId: UUID?
    var name: String
    var kind: ExerciseKind
    var muscleGroup: MuscleGroup
    var equipment: Equipment
    var cardioActivity: CardioActivity?
    var cardioMet: Double?
    var archivedAt: Date?

    var isBuiltIn: Bool  { ownerId == nil }
    var isCardio:  Bool  { kind == .cardio }
    var isWeights: Bool  { kind == .weights }

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId        = "owner_id"
        case name
        case kind
        case muscleGroup    = "muscle_group"
        case equipment
        case cardioActivity = "cardio_activity"
        case cardioMet      = "cardio_met"
        case archivedAt     = "archived_at"
    }
}

enum MuscleGroup: String, Codable, CaseIterable, Identifiable, Sendable {
    case chest      = "Chest"
    case back       = "Back"
    case shoulders  = "Shoulders"
    case biceps     = "Biceps"
    case triceps    = "Triceps"
    case forearms   = "Forearms"
    case quads      = "Quads"
    case hamstrings = "Hamstrings"
    case glutes     = "Glutes"
    case calves     = "Calves"
    case core       = "Core"
    case fullBody   = "Full body"
    case cardio     = "Cardio"

    var id: String { rawValue }

    // Only shown in the weights exercise form
    static var weightsGroups: [MuscleGroup] {
        [.chest, .back, .shoulders, .biceps, .triceps, .forearms,
         .quads, .hamstrings, .glutes, .calves, .core, .fullBody]
    }
}

enum Equipment: String, Codable, CaseIterable, Sendable {
    case barbell      = "Barbell"
    case dumbbell     = "Dumbbell"
    case machine      = "Machine"
    case cable        = "Cable"
    case smithMachine = "Smith machine"
    case kettlebell   = "Kettlebell"
    case bodyweight   = "Bodyweight"
    case band         = "Band"
    case other        = "Other"
    // Cardio-specific built-in equipment
    case treadmill    = "Treadmill"
    case outdoors     = "Outdoors"
    case bike         = "Bike"
    case pool         = "Pool"
}
