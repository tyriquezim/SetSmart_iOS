import Foundation

struct Exercise: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let ownerId: UUID?
    var name: String
    var muscleGroup: MuscleGroup
    var equipment: Equipment
    var archivedAt: Date?

    var isBuiltIn: Bool { ownerId == nil }

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId     = "owner_id"
        case name
        case muscleGroup = "muscle_group"
        case equipment
        case archivedAt  = "archived_at"
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

    var id: String { rawValue }
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
}
