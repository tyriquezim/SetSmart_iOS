import Foundation

// MARK: - Meal

enum Meal: String, CaseIterable, Codable, Identifiable, Sendable {
    case breakfast, lunch, dinner, snack

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .breakfast: "Breakfast"
        case .lunch:     "Lunch"
        case .dinner:    "Dinner"
        case .snack:     "Snacks"
        }
    }

    var systemImage: String {
        switch self {
        case .breakfast: "sun.horizon.fill"
        case .lunch:     "sun.max.fill"
        case .dinner:    "moon.fill"
        case .snack:     "leaf.fill"
        }
    }
}

func defaultMeal() -> Meal {
    let hour = Calendar.current.component(.hour, from: Date())
    if hour < 10 { return .breakfast }
    if hour < 14 { return .lunch }
    if hour >= 17 && hour <= 20 { return .dinner }
    return .snack
}

// MARK: - Food

struct Food: Identifiable, Codable, Sendable {
    let id: UUID
    var source: String          // "custom" | "usda" | "off"
    var sourceId: String?
    var name: String
    var brand: String?
    var barcode: String?
    var baseUnit: String        // "g" | "ml"
    var energyKj: Double
    var proteinG: Double?
    var carbsG: Double?
    var fatG: Double?
    var servingSize: Double?
    var servingLabel: String?
    var archivedAt: Date?
    var userId: UUID?

    enum CodingKeys: String, CodingKey {
        case id, source, name, brand, barcode
        case sourceId     = "source_id"
        case baseUnit     = "base_unit"
        case energyKj     = "energy_kj"
        case proteinG     = "protein_g"
        case carbsG       = "carbs_g"
        case fatG         = "fat_g"
        case servingSize  = "serving_size"
        case servingLabel = "serving_label"
        case archivedAt   = "archived_at"
        case userId       = "user_id"
    }
}

// MARK: - FoodLog

struct FoodLog: Identifiable, Codable, Sendable {
    let id: UUID
    var meal: Meal
    var foodId: UUID?
    var name: String
    var brand: String?
    var amount: Double?
    var amountUnit: String?     // "g" | "ml" | "serving"
    var grams: Double?
    var energyKj: Double
    var proteinG: Double
    var carbsG: Double
    var fatG: Double
    var eatenOn: String         // "YYYY-MM-DD"
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, meal, name, brand, amount, grams
        case foodId     = "food_id"
        case amountUnit = "amount_unit"
        case energyKj   = "energy_kj"
        case proteinG   = "protein_g"
        case carbsG     = "carbs_g"
        case fatG       = "fat_g"
        case eatenOn    = "eaten_on"
        case createdAt  = "created_at"
    }
}

// MARK: - NutritionTargets

struct NutritionTargets: Codable, Sendable {
    var energyKj: Double?
    var proteinG: Double?
    var carbsG: Double?
    var fatG: Double?

    enum CodingKeys: String, CodingKey {
        case energyKj = "energy_kj"
        case proteinG = "protein_g"
        case carbsG   = "carbs_g"
        case fatG     = "fat_g"
    }
}

// MARK: - Recents

struct RecentFood: Identifiable, Sendable {
    var id: UUID { food.id }
    var food: Food
    var lastAmount: Double?
    var lastUnit: String?
}

// MARK: - Nutrition math

func gramsFor(amount: Double, unit: String, servingSize: Double?) -> Double? {
    guard amount > 0 else { return nil }
    if unit == "serving" {
        guard let ss = servingSize, ss > 0 else { return nil }
        return amount * ss
    }
    return amount
}

func computeNutrients(food: Food, grams: Double)
    -> (energyKj: Double, proteinG: Double, carbsG: Double, fatG: Double)
{
    let f = grams / 100
    func r1(_ v: Double) -> Double { (v * 10).rounded() / 10 }
    return (
        energyKj: r1(food.energyKj * f),
        proteinG: r1((food.proteinG ?? 0) * f),
        carbsG:   r1((food.carbsG ?? 0) * f),
        fatG:     r1((food.fatG ?? 0) * f)
    )
}

func amountDescription(amount: Double?, unit: String?, servingSize: Double?) -> String? {
    guard let amount, let unit, amount > 0 else { return nil }
    switch unit {
    case "g":  return "\(Int(amount.rounded())) g"
    case "ml": return "\(Int(amount.rounded())) ml"
    case "serving":
        guard let ss = servingSize else { return nil }
        let g = Int((amount * ss).rounded())
        let aStr = amount.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(amount))" : String(format: "%.1f", amount)
        return "\(aStr) × serving (\(g) g)"
    default: return nil
    }
}

func formatMacro(_ g: Double) -> String {
    if g < 10 { return String(format: "%.1f", g) }
    return "\(Int(g.rounded()))"
}

func formatEnergy(_ kj: Double, unit: EnergyUnit) -> String {
    let value = Int(unit.fromKj(kj).rounded())
    return "\(value.formatted(.number)) \(unit.label)"
}

func formatDecimalInput(_ v: Double) -> String {
    if v.truncatingRemainder(dividingBy: 1) == 0 { return "\(Int(v))" }
    if (v * 10).truncatingRemainder(dividingBy: 1) == 0 { return String(format: "%.1f", v) }
    return String(format: "%.2f", v)
}

// MARK: - Date utilities

extension String {
    static let foodDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        return f
    }()

    static func todayFoodDate() -> String {
        String.foodDateFormatter.string(from: Date())
    }

    static func foodDate(daysFromToday offset: Int) -> String {
        let d = Calendar.current.date(byAdding: .day, value: offset, to: Date()) ?? Date()
        return String.foodDateFormatter.string(from: d)
    }

    func asFoodDate() -> Date? {
        String.foodDateFormatter.date(from: self)
    }
}
