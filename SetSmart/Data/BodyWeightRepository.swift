import Foundation
import Supabase

struct BodyWeightRepository {
    private let db = SupabaseClientProvider.shared

    func fetchLatest(limit: Int = 2) async throws -> [BodyWeight] {
        try await db
            .from("body_weights")
            .select("id,measured_on,weight_kg,body_fat_pct,note")
            .order("measured_on", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    func listBodyWeights() async throws -> [BodyWeight] {
        try await db
            .from("body_weights")
            .select("id,measured_on,weight_kg,body_fat_pct,note")
            .order("measured_on", ascending: true)
            .execute()
            .value
    }

    func logBodyWeight(weightKg: Double, bodyFatPct: Double?, measuredOn: Date, note: String?) async throws {
        let userId = try await db.auth.session.user.id

        struct Payload: Encodable {
            let user_id:      UUID
            let measured_on:  String
            let weight_kg:    Double
            let body_fat_pct: Double?
            let note:         String?

            func encode(to encoder: Encoder) throws {
                var c = encoder.container(keyedBy: CodingKeys.self)
                try c.encode(user_id,     forKey: .user_id)
                try c.encode(measured_on, forKey: .measured_on)
                try c.encode(weight_kg,   forKey: .weight_kg)
                try c.encode(body_fat_pct, forKey: .body_fat_pct)
                try c.encode(note,        forKey: .note)
            }
            enum CodingKeys: String, CodingKey {
                case user_id, measured_on, weight_kg, body_fat_pct, note
            }
        }

        let roundedKg  = (weightKg * 100).rounded() / 100
        let roundedBf  = bodyFatPct.map { ($0 * 10).rounded() / 10 }

        try await db
            .from("body_weights")
            .upsert(
                Payload(
                    user_id:      userId,
                    measured_on:  BodyWeight.dayFormatter.string(from: measuredOn),
                    weight_kg:    roundedKg,
                    body_fat_pct: roundedBf,
                    note:         note?.isEmpty == true ? nil : note
                ),
                onConflict: "user_id,measured_on"
            )
            .execute()
    }

    func deleteBodyWeight(id: UUID) async throws {
        try await db
            .from("body_weights")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
}
