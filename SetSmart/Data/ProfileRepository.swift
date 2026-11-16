import Foundation
import Supabase

struct ProfileRepository {
    private let db = SupabaseClientProvider.shared

    func fetchProfile() async throws -> Profile {
        try await db
            .from("profiles")
            .select()
            .single()
            .execute()
            .value
    }

    func updateProfile(_ profile: Profile) async throws {
        struct Payload: Encodable {
            let display_name:   String?
            let weight_unit:    String
            let energy_unit:    String
            let height_cm:      Double?
            let birth_year:     Int?
            let sex:            String?
            let daily_activity: String?
            let workout_effort: String

            func encode(to encoder: Encoder) throws {
                var c = encoder.container(keyedBy: CodingKeys.self)
                try c.encode(display_name,   forKey: .display_name)
                try c.encode(weight_unit,    forKey: .weight_unit)
                try c.encode(energy_unit,    forKey: .energy_unit)
                try c.encode(height_cm,      forKey: .height_cm)
                try c.encode(birth_year,     forKey: .birth_year)
                try c.encode(sex,            forKey: .sex)
                try c.encode(daily_activity, forKey: .daily_activity)
                try c.encode(workout_effort, forKey: .workout_effort)
            }
            enum CodingKeys: String, CodingKey {
                case display_name, weight_unit, energy_unit,
                     height_cm, birth_year, sex, daily_activity, workout_effort
            }
        }

        try await db
            .from("profiles")
            .update(Payload(
                display_name:   profile.displayName,
                weight_unit:    profile.weightUnit.rawValue,
                energy_unit:    profile.energyUnit.rawValue,
                height_cm:      profile.heightCm,
                birth_year:     profile.birthYear,
                sex:            profile.sex?.rawValue,
                daily_activity: profile.dailyActivity?.rawValue,
                workout_effort: profile.workoutEffort.rawValue
            ))
            .eq("id", value: profile.id.uuidString)
            .execute()
    }
}
