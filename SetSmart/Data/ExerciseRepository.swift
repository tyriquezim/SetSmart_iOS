import Foundation
import Supabase

struct ExerciseRepository {
    private let db = SupabaseClientProvider.shared

    func listExercises() async throws -> [Exercise] {
        try await db
            .from("exercises")
            .select()
            .is("archived_at", value: nil)
            .order("name", ascending: true)
            .execute()
            .value
    }

    func createExercise(name: String, muscleGroup: MuscleGroup, equipment: Equipment) async throws -> Exercise {
        let userId = try await db.auth.session.user.id
        struct Payload: Encodable {
            let owner_id: UUID
            let name: String
            let muscle_group: String
            let equipment: String
        }
        return try await db
            .from("exercises")
            .insert(Payload(
                owner_id: userId,
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                muscle_group: muscleGroup.rawValue,
                equipment: equipment.rawValue
            ))
            .select()
            .single()
            .execute()
            .value
    }

    func updateExercise(_ exercise: Exercise) async throws {
        struct Payload: Encodable {
            let name: String
            let muscle_group: String
            let equipment: String
        }
        try await db
            .from("exercises")
            .update(Payload(
                name: exercise.name.trimmingCharacters(in: .whitespacesAndNewlines),
                muscle_group: exercise.muscleGroup.rawValue,
                equipment: exercise.equipment.rawValue
            ))
            .eq("id", value: exercise.id.uuidString)
            .execute()
    }

    func archiveExercise(id: UUID) async throws {
        struct Payload: Encodable { let archived_at: String }
        try await db
            .from("exercises")
            .update(Payload(archived_at: ISO8601DateFormatter().string(from: Date())))
            .eq("id", value: id.uuidString)
            .execute()
    }
}
