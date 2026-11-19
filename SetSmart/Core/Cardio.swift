import Foundation

// MARK: - Compendium row

struct CardioMetRow: Sendable {
    let code: Int
    let met: Double
    let description: String
    let kmh: Double?   // nil for effort-only rows

    init(code: Int, mph: Double, met: Double, description: String) {
        self.code = code; self.met = met; self.description = description
        self.kmh = mph * 1.609344
    }

    init(code: Int, met: Double, description: String) {
        self.code = code; self.met = met; self.description = description; self.kmh = nil
    }
}

// MARK: - MET source

enum CardioMetSource: Sendable {
    case speed(row: CardioMetRow, speedKmh: Double)
    case effort(row: CardioMetRow, defaulted: Bool)
    case custom(met: Double)
}

// MARK: - Result

struct CardioEnergyResult: Sendable {
    var kcal: Double
    var minutes: Double
    var weightKg: Double
    var restingKcalPerMin: Double
    var met: Double
    var metSource: CardioMetSource
    var activity: CardioActivity
    var distanceM: Double?
    var durationS: Int
}

enum CardioEnergyEstimate: Sendable {
    case result(CardioEnergyResult)
    case missing([MissingDetail])
}

// MARK: - Speed tables (2024 Compendium)

let runSpeedTable: [CardioMetRow] = [
    CardioMetRow(code: 12028, mph: 4.1,  met: 6.5,  description: "Running, 4 to 4.2 mph (13 min/mile)"),
    CardioMetRow(code: 12029, mph: 4.55, met: 7.8,  description: "Running 4.3 to 4.8 mph"),
    CardioMetRow(code: 12030, mph: 5.1,  met: 8.5,  description: "Running, 5.0 to 5.2 mph (12 min/mile)"),
    CardioMetRow(code: 12045, mph: 5.65, met: 9.0,  description: "Running, 5.5-5.8 mph"),
    CardioMetRow(code: 12050, mph: 6.15, met: 9.3,  description: "Running, 6-6.3 mph (10 min/mile)"),
    CardioMetRow(code: 12060, mph: 6.7,  met: 10.5, description: "Running, 6.7 mph (9 min/mile)"),
    CardioMetRow(code: 12070, mph: 7.0,  met: 11.0, description: "Running, 7 mph (8.5 min/mile)"),
    CardioMetRow(code: 12080, mph: 7.5,  met: 11.8, description: "Running, 7.5 mph (8 min/mile)"),
    CardioMetRow(code: 12090, mph: 8.0,  met: 12.0, description: "Running, 8 mph (7.5 min/mile)"),
    CardioMetRow(code: 12100, mph: 8.6,  met: 12.5, description: "Running, 8.6 mph (7 min/mile)"),
    CardioMetRow(code: 12110, mph: 9.0,  met: 13.0, description: "Running, 9 mph (6.5 min/mile)"),
    CardioMetRow(code: 12115, mph: 9.45, met: 14.8, description: "Running, 9.3 to 9.6 mph"),
    CardioMetRow(code: 12120, mph: 10.0, met: 14.8, description: "Running, 10 mph (6 min/mile)"),
    CardioMetRow(code: 12130, mph: 11.0, met: 16.8, description: "Running, 11 mph (5.5 min/mile)"),
    CardioMetRow(code: 12132, mph: 12.0, met: 18.5, description: "Running, 12 mph (5.0 min/mile)"),
    CardioMetRow(code: 12134, mph: 13.0, met: 19.8, description: "Running, 13 mph (4.6 min/mile)"),
    CardioMetRow(code: 12135, mph: 14.0, met: 23.0, description: "Running, 14 mph (4.3 min/mile)"),
]

let walkSpeedTable: [CardioMetRow] = [
    CardioMetRow(code: 17151, mph: 1.7,  met: 2.3, description: "Walking, less than 2.0 mph, level, strolling, very slow"),
    CardioMetRow(code: 17152, mph: 2.2,  met: 2.8, description: "Walking, 2.0 to 2.4 mph, level, slow pace, firm surface"),
    CardioMetRow(code: 17170, mph: 2.5,  met: 3.0, description: "Walking, 2.5 mph, firm, level surface"),
    CardioMetRow(code: 17190, mph: 3.1,  met: 3.8, description: "Walking, 2.8 to 3.4 mph, level, moderate pace, firm surface"),
    CardioMetRow(code: 17200, mph: 3.7,  met: 4.8, description: "Walking, 3.5 to 3.9 mph, level, brisk, firm surface, walking for exercise"),
    CardioMetRow(code: 17220, mph: 4.2,  met: 5.5, description: "Walking, 4.0 to 4.4 mph (6.4 to 7.1 km/h), level, firm surface, very brisk pace"),
    CardioMetRow(code: 17230, mph: 4.7,  met: 7.0, description: "Walking, 4.5 to 4.9 mph, level, firm surface, very, very brisk"),
    CardioMetRow(code: 17231, mph: 5.25, met: 8.5, description: "Walking, 5.0 to 5.5 mph (8.8 to 8.9 km/h), level, firm surface"),
]

let cycleSpeedTable: [CardioMetRow] = [
    CardioMetRow(code: 01018, mph: 5.5,   met: 3.5,  description: "Bicycling, leisure 5.5 mph"),
    CardioMetRow(code: 01019, mph: 9.4,   met: 5.8,  description: "Bicycling, leisure, 9.4 mph"),
    CardioMetRow(code: 01020, mph: 10.95, met: 6.8,  description: "Bicycling, 10-11.9 mph, leisure, slow, light effort"),
    CardioMetRow(code: 01030, mph: 12.95, met: 8.0,  description: "Bicycling, 12-13.9 mph, leisure, moderate effort"),
    CardioMetRow(code: 01040, mph: 14.95, met: 10.0, description: "Bicycling, 14-15.9 mph, racing or leisure, fast, vigorous effort"),
    CardioMetRow(code: 01050, mph: 17.5,  met: 12.0, description: "Bicycling, 16-19 mph, racing/not drafting or >19 mph drafting, very fast, racing general"),
    CardioMetRow(code: 01060, mph: 20.0,  met: 16.8, description: "Bicycling, >20 mph, racing, not drafting"),
]

// MARK: - Effort options per activity

struct CardioEffortOption: Sendable {
    let effort: CardioEffort
    let label: String
    let row: CardioMetRow
}

func effortOptions(for activity: CardioActivity) -> [CardioEffortOption] {
    switch activity {
    case .run:
        return [
            .init(effort: .light,    label: "Easy jog",   row: .init(code: 12020, met: 7.5,  description: "Jogging, general, self-selected pace")),
            .init(effort: .moderate, label: "Steady run",  row: .init(code: 12145, met: 10.5, description: "Running, self-selected pace")),
        ]
    case .walk:
        return [
            .init(effort: .light,    label: "Leisurely", row: .init(code: 17160, met: 3.5, description: "Walking for pleasure (Taylor Code 010)")),
            .init(effort: .moderate, label: "Brisk",      row: .init(code: 17200, met: 4.8, description: "Walking, 3.5 to 3.9 mph, level, brisk, firm surface, walking for exercise")),
        ]
    case .hike:
        return [
            .init(effort: .light,    label: "Slow, gentle hills", row: .init(code: 17081, met: 3.8, description: "Hiking slowly or ambling through fields and hillsides, no load")),
            .init(effort: .moderate, label: "Normal pace",        row: .init(code: 17082, met: 5.3, description: "Hiking or walking at a normal pace through fields and hillsides, no load")),
            .init(effort: .vigorous, label: "With a daypack",     row: .init(code: 17012, met: 7.8, description: "Backpacking, hiking with a daypack, organized walking with daypack")),
        ]
    case .cycle:
        return [
            .init(effort: .light,    label: "Easy",    row: .init(code: 01015, met: 4.3, description: "Bicycling, self-selected easy pace")),
            .init(effort: .moderate, label: "Moderate", row: .init(code: 01016, met: 7.0, description: "Bicycling, self-selected moderate pace")),
            .init(effort: .vigorous, label: "Hard",     row: .init(code: 01017, met: 9.0, description: "Bicycling, self-selected vigorous pace")),
        ]
    case .indoor_cycle:
        return [
            .init(effort: .light,    label: "Light",                   row: .init(code: 01214, met: 4.0, description: "Bicycling, stationary, 50 watts, light effort")),
            .init(effort: .moderate, label: "Moderate",                 row: .init(code: 01200, met: 6.8, description: "Bicycling, stationary, general")),
            .init(effort: .vigorous, label: "Hard, e.g. a spin class",  row: .init(code: 01270, met: 9.0, description: "Bicycling, stationary, RPM/Spin bike class")),
        ]
    case .row:
        return [
            .init(effort: .moderate, label: "Moderate", row: .init(code: 02071, met: 5.0, description: "Rowing, stationary ergometer, general, <100 watts, moderate effort")),
            .init(effort: .vigorous, label: "Hard",      row: .init(code: 02070, met: 7.3, description: "Rowing, stationary ergometer, general, vigorous effort")),
        ]
    case .elliptical:
        return [
            .init(effort: .moderate, label: "Moderate", row: .init(code: 02048, met: 5.0, description: "Elliptical trainer, moderate effort")),
            .init(effort: .vigorous, label: "Hard",      row: .init(code: 02049, met: 9.0, description: "Elliptical trainer, vigorous effort")),
        ]
    case .stairs:
        return [
            .init(effort: .moderate, label: "General", row: .init(code: 02065, met: 9.3, description: "Stair treadmill ergometer, general")),
        ]
    case .swim:
        return [
            .init(effort: .light,    label: "Slow laps",  row: .init(code: 18240, met: 5.8, description: "Swimming laps, freestyle, slow, recreational")),
            .init(effort: .moderate, label: "Steady laps", row: .init(code: 18290, met: 8.0, description: "Swimming, crawl, medium speed, ~50 yards/minute, vigorous effort")),
            .init(effort: .vigorous, label: "Fast laps",   row: .init(code: 18230, met: 9.8, description: "Swimming laps, freestyle, fast, vigorous effort")),
        ]
    case .hiit:
        return [
            .init(effort: .moderate, label: "Moderate",          row: .init(code: 02210, met: 7.0,  description: "High intensity interval exercise, moderate effort")),
            .init(effort: .vigorous, label: "Hard, e.g. Tabata",  row: .init(code: 02214, met: 11.0, description: "High intensity interval exercise, burpees, mountain climbers, squat jumps, Tabata, vigorous effort")),
        ]
    case .other:
        return []
    }
}

// MARK: - MET selection

/// Picks the Compendium MET source from raw inputs. Used for both live estimates and energy calculations.
func cardioMet(
    activity: CardioActivity,
    customMet: Double?,
    durationS: Int,
    distanceM: Double?,
    effort: CardioEffort?
) -> CardioMetSource? {
    // 1. `other`: user-entered MET or no MET
    if activity == .other {
        guard let m = customMet, m > 0 else { return nil }
        return .custom(met: m)
    }

    // 2. Speed table for run/walk/cycle when distance is set
    let speedTable: [CardioMetRow]?
    switch activity {
    case .run:   speedTable = runSpeedTable
    case .walk:  speedTable = walkSpeedTable
    case .cycle: speedTable = cycleSpeedTable
    default:     speedTable = nil
    }
    if let table = speedTable, let distM = distanceM, distM > 0, durationS > 0 {
        let speedKmh = (distM / 1000.0) / (Double(durationS) / 3600.0)
        return .speed(row: nearestSpeedRow(in: table, for: speedKmh), speedKmh: speedKmh)
    }

    // 3. Effort or default
    let options = effortOptions(for: activity)
    guard !options.isEmpty else { return nil }
    if let e = effort, let match = options.first(where: { $0.effort == e }) {
        return .effort(row: match.row, defaulted: false)
    }
    let fallback = options.first(where: { $0.effort == .moderate }) ?? options[0]
    return .effort(row: fallback.row, defaulted: true)
}

func nearestSpeedRow(in table: [CardioMetRow], for speedKmh: Double) -> CardioMetRow {
    guard table.count > 1 else { return table[0] }
    return table.min(by: { a, b in
        abs((a.kmh ?? 0) - speedKmh) < abs((b.kmh ?? 0) - speedKmh)
    }) ?? table[0]
}

func averageSpeedKmh(distanceM: Double, durationS: Int) -> Double? {
    guard distanceM > 0, durationS > 0 else { return nil }
    return (distanceM / 1000.0) / (Double(durationS) / 3600.0)
}

// MARK: - Shared formula helper

/// Energy above resting for any activity. Workouts cap minutes at 180 before calling.
func netActivityKcal(met: Double, minutes: Double, weightKg: Double, restingKcalPerDay: Double) -> Double {
    let gross = met * 3.5 * weightKg / 200.0
    let restPerMin = restingKcalPerDay / 1440.0
    return max(0, gross - restPerMin) * minutes
}

// MARK: - Single cardio estimate (from a WorkoutCardioRow)

func estimateCardioEnergy(
    activity:  CardioActivity,
    customMet: Double?,
    durationS: Int,
    distanceM: Double?,
    effort:    CardioEffort?,
    startedAt: Date,
    weights:   [BodyWeight],
    profile:   Profile
) -> CardioEnergyEstimate {
    let dayStr = localDayString(from: startedAt)

    guard let stats = bodyStatsOn(day: dayStr, weights: weights, profile: profile) else {
        var missing = missingDetails(stats: nil, profile: profile)
        if activity == .other, (customMet ?? 0) <= 0 { missing.append(.met) }
        return .missing(missing)
    }
    guard let resting = restingEnergy(stats: stats) else {
        var missing = missingDetails(stats: stats, profile: profile)
        if activity == .other, (customMet ?? 0) <= 0 { missing.append(.met) }
        return .missing(missing)
    }
    guard let metSrc = cardioMet(activity: activity, customMet: customMet,
                                  durationS: durationS, distanceM: distanceM, effort: effort) else {
        return .missing([.met])
    }

    let met: Double
    switch metSrc {
    case .speed(let row, _):  met = row.met
    case .effort(let row, _): met = row.met
    case .custom(let m):      met = m
    }

    let minutes = Double(durationS) / 60.0
    let kcal = netActivityKcal(met: met, minutes: minutes,
                                weightKg: stats.weightKg, restingKcalPerDay: resting.kcalPerDay)
    return .result(CardioEnergyResult(
        kcal:              kcal,
        minutes:           minutes,
        weightKg:          stats.weightKg,
        restingKcalPerMin: resting.kcalPerDay / 1440.0,
        met:               met,
        metSource:         metSrc,
        activity:          activity,
        distanceM:         distanceM,
        durationS:         durationS
    ))
}

// Convenience for WorkoutCardioRow
extension WorkoutCardioRow {
    func energyEstimate(weights: [BodyWeight], profile: Profile) -> CardioEnergyEstimate {
        estimateCardioEnergy(
            activity:  activity,
            customMet: exercise?.cardioMet,
            durationS: durationS,
            distanceM: distanceM,
            effort:    effort,
            startedAt: startedAt,
            weights:   weights,
            profile:   profile
        )
    }
}

// MARK: - Cardio summary text

func cardioSummaryText(durationS: Int, distanceM: Double?, activity: CardioActivity, weightUnit: WeightUnit) -> String {
    var parts = [formatCardioTime(durationS)]
    if let dist = distanceM, dist > 0 {
        parts.append(formatDistanceDisplay(metres: dist, activity: activity, weightUnit: weightUnit))
        if let pace = formatPace(distanceM: dist, durationS: durationS, activity: activity, weightUnit: weightUnit) {
            parts.append(pace)
        }
    }
    return parts.joined(separator: " · ")
}

// MARK: - Pace / distance formatting

func formatPace(distanceM: Double, durationS: Int, activity: CardioActivity, weightUnit: WeightUnit) -> String? {
    guard distanceM > 0, durationS > 0 else { return nil }
    switch activity {
    case .swim:
        let secsPer100 = Double(durationS) / (distanceM / 100.0)
        return "\(paceMMSS(secsPer100)) /100 m"
    case .row:
        let secsPer500 = Double(durationS) / (distanceM / 500.0)
        return "\(paceMMSS(secsPer500)) /500 m"
    case .cycle, .indoor_cycle:
        let speedKmh = (distanceM / 1000.0) / (Double(durationS) / 3600.0)
        if weightUnit == .lb {
            return String(format: "%.1f mph", speedKmh / 1.609344)
        }
        return String(format: "%.1f km/h", speedKmh)
    default:
        if weightUnit == .lb {
            let secsPerMile = Double(durationS) / (distanceM / 1609.344)
            return "\(paceMMSS(secsPerMile)) /mi"
        }
        let secsPerKm = Double(durationS) / (distanceM / 1000.0)
        return "\(paceMMSS(secsPerKm)) /km"
    }
}

private func paceMMSS(_ totalSeconds: Double) -> String {
    let s = Int(totalSeconds.rounded())
    return String(format: "%d:%02d", s / 60, s % 60)
}

func formatDistanceDisplay(metres: Double, activity: CardioActivity, weightUnit: WeightUnit) -> String {
    if activity.usesMetres { return "\(Int(metres.rounded())) m" }
    if weightUnit == .lb    { return String(format: "%.2f mi", metres / 1609.344) }
    return String(format: "%.2f km", metres / 1000.0)
}

func distanceInDisplayUnit(metres: Double, activity: CardioActivity, weightUnit: WeightUnit) -> Double {
    if activity.usesMetres { return metres }
    if weightUnit == .lb    { return metres / 1609.344 }
    return metres / 1000.0
}

func distanceToMetres(value: Double, activity: CardioActivity, weightUnit: WeightUnit) -> Double {
    if activity.usesMetres { return value }
    if weightUnit == .lb    { return value * 1609.344 }
    return value * 1000.0
}

func distanceSuffix(activity: CardioActivity, weightUnit: WeightUnit) -> String {
    if activity.usesMetres { return "m" }
    return weightUnit == .lb ? "mi" : "km"
}

func speedLabel(activity: CardioActivity) -> String {
    switch activity {
    case .cycle, .indoor_cycle: return "Avg speed"
    default:                    return "Avg pace"
    }
}
