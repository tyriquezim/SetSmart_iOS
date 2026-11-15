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
            let display_name: String?
            let weight_unit: String
            let energy_unit: String
        }

        try await db
            .from("profiles")
            .update(Payload(
                display_name: profile.displayName,
                weight_unit:  profile.weightUnit.rawValue,
                energy_unit:  profile.energyUnit.rawValue
            ))
            .eq("id", value: profile.id.uuidString)
            .execute()
    }
}
