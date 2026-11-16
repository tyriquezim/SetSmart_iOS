import Foundation

// MARK: - Body weight

struct BodyWeight: Identifiable, Codable, Sendable {
    let id: UUID
    var measuredOn: String  // "YYYY-MM-DD" — Postgres date column
    var weightKg: Double
    var bodyFatPct: Double? // optional, 3–70
    var note: String?

    var date: Date { Self.dayFormatter.date(from: measuredOn) ?? .distantPast }

    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone   = TimeZone(secondsFromGMT: 0)
        return f
    }()

    enum CodingKeys: String, CodingKey {
        case id
        case measuredOn  = "measured_on"
        case weightKg    = "weight_kg"
        case bodyFatPct  = "body_fat_pct"
        case note
    }
}

// MARK: - Lifts list aggregate

struct ExerciseSummary: Identifiable, Sendable {
    let id: UUID               // exercise ID
    var exercise: Exercise
    var lastPerformedAt: Date
    var bestE1rmKg: Double?
    var maxWeightKg: Double?
    var maxReps: Int
    var isPrimarilyBodyweight: Bool   // true when no weight ever logged
    var sparklinePoints: [Double]     // last ≤15 primary-metric values, oldest first
}

// MARK: - Per-exercise records (first session to reach each peak)

struct ExerciseRecords: Sendable {
    var bestE1rm: (value: Double, date: Date)?
    var heaviest: (value: Double, date: Date)?
    var bestVolume: (value: Double, date: Date)?
    var bestReps:   (value: Int,    date: Date)?
}

// MARK: - UI enums

enum ProgressRange: String, CaseIterable, Sendable {
    case oneMonth    = "1M"
    case threeMonths = "3M"
    case sixMonths   = "6M"
    case oneYear     = "1Y"
    case all         = "All"

    var days: Int? {
        switch self {
        case .oneMonth:    return 30
        case .threeMonths: return 91
        case .sixMonths:   return 182
        case .oneYear:     return 365
        case .all:         return nil
        }
    }
}

enum LiftMetric: String, CaseIterable, Sendable {
    case e1rm   = "e1RM"
    case weight = "Weight"
    case volume = "Volume"
    case reps   = "Reps"
}

// MARK: - Math utilities

/// 7-day trailing average. For each point, mean of all points whose date is
/// within the previous 6 days (inclusive), using local calendar days.
func sevenDayAverage(_ points: [(date: Date, value: Double)]) -> [(date: Date, avg: Double)] {
    let cal    = Calendar.current
    let sorted = points.sorted { $0.date < $1.date }
    return sorted.map { entry in
        let cutoff = cal.date(byAdding: .day, value: -6, to: cal.startOfDay(for: entry.date))!
        let window = sorted.filter {
            let d = cal.startOfDay(for: $0.date)
            return d >= cutoff && d <= cal.startOfDay(for: entry.date)
        }
        let avg = window.map(\.value).reduce(0, +) / Double(window.count)
        return (entry.date, avg)
    }
}

/// Latest value minus the value of the most-recent point at least `days` before the latest.
/// Returns nil when fewer than 2 points exist or no such baseline exists.
func changeOver(_ points: [(date: Date, value: Double)], days: Int) -> Double? {
    guard points.count >= 2 else { return nil }
    let sorted = points.sorted { $0.date < $1.date }
    guard let latest = sorted.last else { return nil }
    let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: latest.date)!
    guard let baseline = sorted.last(where: { $0.date <= cutoff }) else { return nil }
    return latest.value - baseline.value
}

/// Compute ExerciseRecords: the first session to hit each peak value wins.
func computeRecords(_ sessions: [ExerciseSessionStats]) -> ExerciseRecords {
    var bestE1rm:   (Double, Date)?
    var heaviest:   (Double, Date)?
    var bestVolume: (Double, Date)?
    var bestReps:   (Int, Date)?

    for s in sessions.sorted(by: { $0.startedAt < $1.startedAt }) {
        if let v = s.bestE1rmKg?.value,  v > 0, (bestE1rm   == nil || v > bestE1rm!.0)   { bestE1rm   = (v, s.startedAt) }
        if let v = s.maxWeightKg?.value, v > 0, (heaviest   == nil || v > heaviest!.0)   { heaviest   = (v, s.startedAt) }
        if let v = s.volumeKg?.value,    v > 0, (bestVolume == nil || v > bestVolume!.0) { bestVolume = (v, s.startedAt) }
        if s.maxReps > 0, (bestReps == nil || s.maxReps > bestReps!.0)                   { bestReps   = (s.maxReps, s.startedAt) }
    }

    return ExerciseRecords(
        bestE1rm:   bestE1rm.map   { (value: $0.0, date: $0.1) },
        heaviest:   heaviest.map   { (value: $0.0, date: $0.1) },
        bestVolume: bestVolume.map { (value: $0.0, date: $0.1) },
        bestReps:   bestReps.map   { (value: $0.0, date: $0.1) }
    )
}
