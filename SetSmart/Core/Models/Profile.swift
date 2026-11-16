import Foundation

struct Profile: Sendable {
    let id: UUID
    var displayName: String?
    var weightUnit: WeightUnit
    var energyUnit: EnergyUnit
    var heightCm: Double?
    var birthYear: Int?
    var sex: Sex?
    var dailyActivity: DailyActivity?
    var workoutEffort: WorkoutEffort

    var firstName: String? {
        displayName?.components(separatedBy: " ").first
    }
}

extension Profile: Codable {
    enum CodingKeys: String, CodingKey {
        case id
        case displayName   = "display_name"
        case weightUnit    = "weight_unit"
        case energyUnit    = "energy_unit"
        case heightCm      = "height_cm"
        case birthYear     = "birth_year"
        case sex
        case dailyActivity = "daily_activity"
        case workoutEffort = "workout_effort"
    }

    init(from decoder: Decoder) throws {
        let c          = try decoder.container(keyedBy: CodingKeys.self)
        id             = try c.decode(UUID.self,       forKey: .id)
        displayName    = try c.decodeIfPresent(String.self,       forKey: .displayName)
        weightUnit     = try c.decode(WeightUnit.self,            forKey: .weightUnit)
        energyUnit     = try c.decode(EnergyUnit.self,            forKey: .energyUnit)
        heightCm       = try c.decodeIfPresent(Double.self,       forKey: .heightCm)
        birthYear      = try c.decodeIfPresent(Int.self,          forKey: .birthYear)
        sex            = try c.decodeIfPresent(Sex.self,          forKey: .sex)
        dailyActivity  = try c.decodeIfPresent(DailyActivity.self, forKey: .dailyActivity)
        workoutEffort  = (try c.decodeIfPresent(WorkoutEffort.self, forKey: .workoutEffort)) ?? .moderate
    }
}

// MARK: - Body-detail enums

enum Sex: String, Codable, CaseIterable, Sendable {
    case male, female
    var label: String { rawValue.capitalized }
}

enum DailyActivity: String, Codable, CaseIterable, Sendable {
    case sitting, mixed, active

    var pal: Double {
        switch self {
        case .sitting: return 1.4
        case .mixed:   return 1.55
        case .active:  return 1.75
        }
    }
    var label: String {
        switch self {
        case .sitting: return "Mostly sitting"
        case .mixed:   return "Mix of sitting and moving"
        case .active:  return "On your feet most of the day"
        }
    }
    var hint: String {
        switch self {
        case .sitting: return "Desk job, little walking outside workouts"
        case .mixed:   return "Some walking or standing through the day"
        case .active:  return "e.g. retail, nursing, trades"
        }
    }
    var palLabel: String { String(format: "%.2f", pal) }
}

enum WorkoutEffort: String, Codable, CaseIterable, Sendable {
    case moderate, vigorous

    var label: String { rawValue.capitalized }
    var met: Double {
        switch self {
        case .moderate: return 3.5
        case .vigorous: return 6.0
        }
    }
    var hint: String {
        switch self {
        case .moderate: return "Several exercises, mostly 8–15 reps, normal rests."
        case .vigorous: return "Heavy powerlifting or bodybuilding sessions, pushing hard with short rests."
        }
    }
}

// MARK: - Units

enum WeightUnit: String, Codable, CaseIterable, Sendable {
    case kg, lb

    var label: String { rawValue }

    // Multiplier to convert kg → this unit
    var kgFactor: Double {
        switch self {
        case .kg: return 1.0
        case .lb: return 2.2046226218
        }
    }

    func fromKg(_ kg: Double) -> Double { kg * kgFactor }
    func toKg(_ value: Double) -> Double { value / kgFactor }

    var stepSize: Double {
        switch self {
        case .kg: return 2.5
        case .lb: return 5.0
        }
    }
}

enum EnergyUnit: String, Codable, CaseIterable, Sendable {
    case kj, kcal

    var label: String {
        switch self {
        case .kj:   return "kJ"
        case .kcal: return "kcal"
        }
    }

    // Multiplier to convert kJ → this unit
    var kjFactor: Double {
        switch self {
        case .kj:   return 1.0
        case .kcal: return 1.0 / 4.184
        }
    }

    func fromKj(_ kj: Double) -> Double { kj * kjFactor }
    func toKj(_ value: Double) -> Double { value / kjFactor }
}
