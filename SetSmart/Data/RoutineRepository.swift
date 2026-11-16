import Foundation
import Supabase

struct RoutineRepository {
    private let db = SupabaseClientProvider.shared

    func listRoutines() async throws -> [RoutineSummary] {
        try await db
            .from("routines")
            .select("id,name,notes,updated_at,routine_exercises(count)")
            .order("updated_at", ascending: false)
            .execute()
            .value
    }

    func loadRoutine(id: UUID) async throws -> Routine {
        try await db
            .from("routines")
            .select("id,name,notes,updated_at,routine_exercises(exercise_id,position,rest_seconds,sets,notes,exercise:exercises(*))")
            .eq("id", value: id.uuidString)
            .order("position", ascending: true, referencedTable: "routine_exercises")
            .single()
            .execute()
            .value
    }

    func saveRoutine(id: UUID?, name: String, notes: String?, exercises: [SaveRoutineExercise]) async throws -> UUID {
        // Custom encode so nil values are sent as JSON null, not omitted.
        // PostgREST matches functions by their full parameter list; omitting nil keys
        // causes it to look for a 2-argument overload that doesn't exist.
        struct Payload: Encodable {
            let p_routine_id: UUID?
            let p_name: String
            let p_notes: String?
            let p_exercises: [SaveRoutineExercise]

            enum CodingKeys: String, CodingKey {
                case p_routine_id, p_name, p_notes, p_exercises
            }

            func encode(to encoder: any Encoder) throws {
                var c = encoder.container(keyedBy: CodingKeys.self)
                try c.encode(p_routine_id, forKey: .p_routine_id)
                try c.encode(p_name,       forKey: .p_name)
                try c.encode(p_notes,      forKey: .p_notes)
                try c.encode(p_exercises,  forKey: .p_exercises)
            }
        }
        let uuidString: String = try await db
            .rpc("save_routine", params: Payload(
                p_routine_id: id,
                p_name: name,
                p_notes: notes,
                p_exercises: exercises
            ))
            .execute()
            .value
        return UUID(uuidString: uuidString) ?? (id ?? UUID())
    }

    func deleteRoutine(id: UUID) async throws {
        try await db
            .from("routines")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
}

struct SaveRoutineExercise: Encodable {
    let exercise_id: UUID
    let position: Int
    let rest_seconds: Int
    let sets: [SavePlannedSet]
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case exercise_id, position, rest_seconds, sets, notes
    }

    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(exercise_id,  forKey: .exercise_id)
        try c.encode(position,     forKey: .position)
        try c.encode(rest_seconds, forKey: .rest_seconds)
        try c.encode(sets,         forKey: .sets)
        try c.encode(notes,        forKey: .notes)
    }
}

struct SavePlannedSet: Encodable {
    let reps: Int
    let weight_kg: Double?

    enum CodingKeys: String, CodingKey {
        case reps, weight_kg
    }

    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(reps,      forKey: .reps)
        try c.encode(weight_kg, forKey: .weight_kg)
    }
}

enum SSError: LocalizedError
{
    case invalidResponse
    var errorDescription: String? { "Unexpected response from server." }
}
