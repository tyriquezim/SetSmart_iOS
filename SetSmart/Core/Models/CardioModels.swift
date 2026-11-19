import Foundation

// MARK: - Activity

enum CardioActivity: String, Codable, CaseIterable, Sendable {
    case run, walk, hike, cycle, indoor_cycle, row, elliptical, stairs, swim, hiit, other

    static var displayOrder: [CardioActivity] {
        [.run, .walk, .cycle, .indoor_cycle, .swim, .row, .elliptical, .stairs, .hike, .hiit, .other]
    }

    var label: String {
        switch self {
        case .run:          return "Run"
        case .walk:         return "Walk"
        case .hike:         return "Hike"
        case .cycle:        return "Ride (outdoor)"
        case .indoor_cycle: return "Exercise bike"
        case .swim:         return "Swim"
        case .row:          return "Rowing machine"
        case .elliptical:   return "Elliptical"
        case .stairs:       return "Stair climber"
        case .hiit:         return "HIIT"
        case .other:        return "Other"
        }
    }

    var systemImage: String {
        switch self {
        case .run:          return "figure.run"
        case .walk:         return "figure.walk"
        case .hike:         return "figure.hiking"
        case .cycle:        return "figure.outdoor.cycle"
        case .indoor_cycle: return "bicycle"
        case .swim:         return "figure.pool.swim"
        case .row:          return "figure.rowing"
        case .elliptical:   return "figure.elliptical"
        case .stairs:       return "figure.stair.stepper"
        case .hiit:         return "bolt.heart.fill"
        case .other:        return "questionmark.circle"
        }
    }

    // Activities that accept a distance input
    var hasDistance: Bool {
        switch self {
        case .run, .walk, .hike, .cycle, .row, .swim, .other: return true
        default: return false
        }
    }

    // swim and row always use metres regardless of weight unit
    var usesMetres: Bool { self == .row || self == .swim }

    // These activities pick MET by speed when distance is set
    var hasSpeedTable: Bool { self == .run || self == .walk || self == .cycle }
}

// MARK: - Effort

enum CardioEffort: String, Codable, CaseIterable, Sendable {
    case light, moderate, vigorous
    var label: String { rawValue.capitalized }
}
