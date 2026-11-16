import Foundation
import Supabase

struct FoodRepository {
    private let db = SupabaseClientProvider.shared

    // MARK: - Food logs

    func fetchLogs(from: String, to: String) async throws -> [FoodLog] {
        try await db
            .from("food_logs")
            .select("*")
            .gte("eaten_on", value: from)
            .lte("eaten_on", value: to)
            .order("created_at", ascending: true)
            .execute()
            .value
    }

    func addFoodLog(
        meal: Meal,
        eatenOn: String,
        food: Food,
        amount: Double,
        amountUnit: String,
        grams: Double,
        energyKj: Double,
        proteinG: Double,
        carbsG: Double,
        fatG: Double
    ) async throws -> FoodLog {
        let savedFood: Food = (food.source != "custom" && food.sourceId != nil)
            ? (try await upsertFood(food))
            : food

        struct Payload: Encodable {
            var meal: String
            var food_id: UUID
            var name: String
            var brand: String?
            var amount: Double
            var amount_unit: String
            var grams: Double
            var energy_kj: Double
            var protein_g: Double
            var carbs_g: Double
            var fat_g: Double
            var eaten_on: String
        }

        return try await db
            .from("food_logs")
            .insert(Payload(
                meal: meal.rawValue, food_id: savedFood.id,
                name: savedFood.name, brand: savedFood.brand,
                amount: amount, amount_unit: amountUnit, grams: grams,
                energy_kj: energyKj, protein_g: proteinG,
                carbs_g: carbsG, fat_g: fatG, eaten_on: eatenOn
            ))
            .select()
            .single()
            .execute()
            .value
    }

    func addQuickLog(
        meal: Meal, eatenOn: String, name: String, brand: String?,
        energyKj: Double, proteinG: Double, carbsG: Double, fatG: Double
    ) async throws -> FoodLog {
        struct Payload: Encodable {
            var meal: String; var name: String; var brand: String?
            var energy_kj: Double; var protein_g: Double
            var carbs_g: Double; var fat_g: Double; var eaten_on: String
        }
        return try await db
            .from("food_logs")
            .insert(Payload(
                meal: meal.rawValue, name: name, brand: brand,
                energy_kj: energyKj, protein_g: proteinG,
                carbs_g: carbsG, fat_g: fatG, eaten_on: eatenOn
            ))
            .select()
            .single()
            .execute()
            .value
    }

    func deleteLog(id: UUID) async throws {
        try await db
            .from("food_logs")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    // MARK: - Recents

    func fetchRecents() async throws -> [RecentFood] {
        struct Entry: Codable {
            var amount: Double?
            var amountUnit: String?
            var food: Food?
            enum CodingKeys: String, CodingKey {
                case amount; case amountUnit = "amount_unit"; case food
            }
        }
        let entries: [Entry] = try await db
            .from("food_logs")
            .select("amount,amount_unit,food:foods(*)")
            .order("created_at", ascending: false)
            .limit(200)
            .execute()
            .value

        var seen: Set<UUID> = []
        var result: [RecentFood] = []
        for e in entries {
            guard let food = e.food, food.archivedAt == nil, !seen.contains(food.id) else { continue }
            seen.insert(food.id)
            result.append(RecentFood(food: food, lastAmount: e.amount, lastUnit: e.amountUnit))
            if result.count >= 30 { break }
        }
        return result
    }

    // MARK: - My Foods

    func fetchMyFoods() async throws -> [Food] {
        try await db
            .from("foods")
            .select("*")
            .eq("source", value: "custom")
            .is("archived_at", value: nil)
            .order("name", ascending: true)
            .execute()
            .value
    }

    @discardableResult
    func upsertFood(_ food: Food) async throws -> Food {
        let userId = try await db.auth.session.user.id
        struct Payload: Encodable {
            var source: String; var source_id: String?; var name: String
            var brand: String?; var barcode: String?; var base_unit: String
            var energy_kj: Double; var protein_g: Double?; var carbs_g: Double?; var fat_g: Double?
            var serving_size: Double?; var serving_label: String?; var user_id: UUID
        }
        return try await db
            .from("foods")
            .upsert(Payload(
                source: food.source, source_id: food.sourceId, name: food.name,
                brand: food.brand, barcode: food.barcode, base_unit: food.baseUnit,
                energy_kj: food.energyKj, protein_g: food.proteinG,
                carbs_g: food.carbsG, fat_g: food.fatG,
                serving_size: food.servingSize, serving_label: food.servingLabel,
                user_id: userId
            ), onConflict: "user_id,source,source_id")
            .select()
            .single()
            .execute()
            .value
    }

    func createCustomFood(_ food: Food) async throws -> Food {
        try await upsertFood(food)
    }

    func updateCustomFood(_ food: Food) async throws {
        struct Payload: Encodable {
            var name: String; var brand: String?; var barcode: String?; var base_unit: String
            var energy_kj: Double; var protein_g: Double?; var carbs_g: Double?; var fat_g: Double?
            var serving_size: Double?; var serving_label: String?
        }
        try await db
            .from("foods")
            .update(Payload(
                name: food.name, brand: food.brand, barcode: food.barcode,
                base_unit: food.baseUnit, energy_kj: food.energyKj,
                protein_g: food.proteinG, carbs_g: food.carbsG, fat_g: food.fatG,
                serving_size: food.servingSize, serving_label: food.servingLabel
            ))
            .eq("id", value: food.id.uuidString)
            .execute()
    }

    func archiveFood(id: UUID) async throws {
        struct Payload: Encodable { var archived_at: String }
        let iso = ISO8601DateFormatter()
        try await db
            .from("foods")
            .update(Payload(archived_at: iso.string(from: Date())))
            .eq("id", value: id.uuidString)
            .execute()
    }

    // MARK: - Nutrition targets

    func fetchTargets() async throws -> NutritionTargets? {
        try await db
            .from("nutrition_targets")
            .select("energy_kj,protein_g,carbs_g,fat_g")
            .maybeSingle()
            .execute()
            .value
    }

    func saveTargets(_ targets: NutritionTargets) async throws {
        let userId = try await db.auth.session.user.id
        struct Payload: Encodable {
            var user_id: UUID
            var energy_kj: Double?; var protein_g: Double?
            var carbs_g: Double?; var fat_g: Double?
        }
        try await db
            .from("nutrition_targets")
            .upsert(Payload(
                user_id: userId,
                energy_kj: targets.energyKj, protein_g: targets.proteinG,
                carbs_g: targets.carbsG, fat_g: targets.fatG
            ), onConflict: "user_id")
            .execute()
    }
}
