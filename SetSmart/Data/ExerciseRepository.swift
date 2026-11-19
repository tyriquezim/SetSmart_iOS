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
            let kind: String
            let muscle_group: String
            let equipment: String
        }
        return try await db
            .from("exercises")
            .insert(Payload(
                owner_id:     userId,
                name:         name.trimmingCharacters(in: .whitespacesAndNewlines),
                kind:         ExerciseKind.weights.rawValue,
                muscle_group: muscleGroup.rawValue,
                equipment:    equipment.rawValue
            ))
            .select()
            .single()
            .execute()
            .value
    }

    func createCardioExercise(
        name: String,
        activity: CardioActivity,
        equipment: Equipment,
        customMet: Double?
    ) async throws -> Exercise {
        let userId = try await db.auth.session.user.id
        struct Payload: Encodable {
            let owner_id: UUID
            let name: String
            let kind: String
            let muscle_group: String
            let equipment: String
            let cardio_activity: String
            let cardio_met: Double?

            func encode(to encoder: any Encoder) throws {
                var c = encoder.container(keyedBy: CodingKeys.self)
                try c.encode(owner_id,        forKey: .owner_id)
                try c.encode(name,            forKey: .name)
                try c.encode(kind,            forKey: .kind)
                try c.encode(muscle_group,    forKey: .muscle_group)
                try c.encode(equipment,       forKey: .equipment)
                try c.encode(cardio_activity, forKey: .cardio_activity)
                try c.encode(cardio_met,      forKey: .cardio_met)
            }
            enum CodingKeys: String, CodingKey {
                case owner_id, name, kind, muscle_group, equipment, cardio_activity, cardio_met
            }
        }
        return try await db
            .from("exercises")
            .insert(Payload(
                owner_id:        userId,
                name:            name.trimmingCharacters(in: .whitespacesAndNewlines),
                kind:            ExerciseKind.cardio.rawValue,
                muscle_group:    MuscleGroup.cardio.rawValue,
                equipment:       equipment.rawValue,
                cardio_activity: activity.rawValue,
                cardio_met:      customMet
            ))
            .select()
            .single()
            .execute()
            .value
    }

    func updateExercise(_ exercise: Exercise) async throws {
        if exercise.isCardio {
            struct CardioPayload: Encodable {
                let name: String
                let equipment: String
                let cardio_activity: String?
                let cardio_met: Double?

                func encode(to encoder: any Encoder) throws {
                    var c = encoder.container(keyedBy: CodingKeys.self)
                    try c.encode(name,            forKey: .name)
                    try c.encode(equipment,       forKey: .equipment)
                    try c.encode(cardio_activity, forKey: .cardio_activity)
                    try c.encode(cardio_met,      forKey: .cardio_met)
                }
                enum CodingKeys: String, CodingKey {
                    case name, equipment, cardio_activity, cardio_met
                }
            }
            try await db
                .from("exercises")
                .update(CardioPayload(
                    name:            exercise.name.trimmingCharacters(in: .whitespacesAndNewlines),
                    equipment:       exercise.equipment.rawValue,
                    cardio_activity: exercise.cardioActivity?.rawValue,
                    cardio_met:      exercise.cardioMet
                ))
                .eq("id", value: exercise.id.uuidString)
                .execute()
        } else {
            struct WeightsPayload: Encodable {
                let name: String
                let muscle_group: String
                let equipment: String
            }
            try await db
                .from("exercises")
                .update(WeightsPayload(
                    name:         exercise.name.trimmingCharacters(in: .whitespacesAndNewlines),
                    muscle_group: exercise.muscleGroup.rawValue,
                    equipment:    exercise.equipment.rawValue
                ))
                .eq("id", value: exercise.id.uuidString)
                .execute()
        }
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
