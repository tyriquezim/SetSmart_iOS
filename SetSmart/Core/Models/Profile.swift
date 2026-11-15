import Foundation

struct Profile: Codable, Sendable {
    let id: UUID
    var displayName: String?
    var weightUnit: WeightUnit
    var energyUnit: EnergyUnit

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case weightUnit  = "weight_unit"
        case energyUnit  = "energy_unit"
    }

    var firstName: String? {
        displayName?.components(separatedBy: " ").first
    }
}

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
