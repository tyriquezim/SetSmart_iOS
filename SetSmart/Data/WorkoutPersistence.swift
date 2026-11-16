import Foundation

struct WorkoutPersistenceFile: Codable {
    let userId: UUID
    let workout: WorkoutState
}

struct WorkoutPersistence {
    private static let filename = "workout.json"

    private static var url: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
    }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    func save(_ workout: WorkoutState, userId: UUID) {
        do {
            let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let data = try Self.encoder.encode(WorkoutPersistenceFile(userId: userId, workout: workout))
            try data.write(to: Self.url, options: .atomic)
        } catch { /* non-fatal */ }
    }

    func load(for userId: UUID) -> WorkoutState? {
        guard let data = try? Data(contentsOf: Self.url),
              let file = try? Self.decoder.decode(WorkoutPersistenceFile.self, from: data),
              file.userId == userId else { return nil }
        return file.workout
    }

    func delete() {
        try? FileManager.default.removeItem(at: Self.url)
    }
}
