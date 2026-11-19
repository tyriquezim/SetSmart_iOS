import Foundation

struct WorkoutOutboxItem: Codable {
    let userId: UUID
    let state: WorkoutState
    let notes: String?
}

// Persists failed workout saves so they can be retried later.
// log_workout is idempotent (same UUID is a no-op), so retries are safe.
struct WorkoutOutbox {
    private static let filename = "workout_outbox.json"

    private static var url: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
    }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d
    }()

    func add(state: WorkoutState, notes: String?, userId: UUID) {
        var items = loadAll()
        // Avoid duplicates by workout id
        items.removeAll { $0.state.id == state.id }
        items.append(WorkoutOutboxItem(userId: userId, state: state, notes: notes))
        persist(items)
    }

    func drain(for userId: UUID, using repo: WorkoutRepository) async {
        var items = loadAll().filter { $0.userId == userId }
        guard !items.isEmpty else { return }

        var remaining: [WorkoutOutboxItem] = []
        for item in items {
            do {
                try await repo.logWorkout(state: item.state, notes: item.notes)
            } catch {
                remaining.append(item)
            }
        }

        // Keep only items that still failed (or belong to other users)
        let otherUsers = loadAll().filter { $0.userId != userId }
        persist(otherUsers + remaining)
    }

    func count(for userId: UUID) -> Int {
        loadAll().filter { $0.userId == userId }.count
    }

    func deleteAll(for userId: UUID) {
        let others = loadAll().filter { $0.userId != userId }
        persist(others)
    }

    private func loadAll() -> [WorkoutOutboxItem] {
        guard let data = try? Data(contentsOf: Self.url) else { return [] }
        return (try? Self.decoder.decode([WorkoutOutboxItem].self, from: data)) ?? []
    }

    private func persist(_ items: [WorkoutOutboxItem]) {
        do {
            let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            if items.isEmpty {
                try? FileManager.default.removeItem(at: Self.url)
            } else {
                let data = try Self.encoder.encode(items)
                try data.write(to: Self.url, options: .atomic)
            }
        } catch { /* non-fatal */ }
    }
}
