import Foundation

// MARK: - Input type

struct BodyStats: Sendable {
    var weightKg: Double
    var bodyFatPct: Double?
    var heightCm: Double?
    var age: Int?
    var sex: Sex?
    var dailyActivity: DailyActivity?
    var workoutEffort: WorkoutEffort
}

// MARK: - Result types

enum MissingDetail: String, Sendable, Equatable {
    case weight, height, birthYear, met

    var phrase: String {
        switch self {
        case .weight:    return "log your weight"
        case .height:    return "add your height"
        case .birthYear: return "add your birth year"
        case .met:       return "add a MET value"
        }
    }
}

struct RestingEnergyResult: Sendable {
    enum Method: Sendable, Equatable {
        case cunningham(ffmKg: Double)
        case mifflin             // sex was explicitly set
        case mifflinAverage      // sex not set, used average of male + female
    }
    var kcalPerDay: Double
    var method: Method
}

struct WorkoutEnergyResult: Sendable {
    var kcal: Double
    var minutes: Double
    var capped: Bool
    var met: Double
    var weightKg: Double
    var restingKcalPerMin: Double
    var effort: WorkoutEffort
}

/// Full workout energy including both weight-training and embedded cardio breakdowns.
struct WorkoutEnergyFull: Sendable {
    var weightsKcal: Double
    var weightsMinutes: Double
    var weightsCapped: Bool
    var weightsMet: Double
    var weightsEffort: WorkoutEffort
    var cardioKcal: Double
    var cardioEstimates: [(name: String, estimate: CardioEnergyEstimate)]
    var weightKg: Double
    var restingKcalPerMin: Double
    var restingResult: RestingEnergyResult

    var totalKcal: Double { weightsKcal + cardioKcal }
}

struct DayEnergyComponents: Sendable {
    var restingKcal: Double
    var everydayKcal: Double
    var workoutKcal: Double
    var cardioKcal: Double
    var activityAssumed: Bool
    var pal: Double
    var restingResult: RestingEnergyResult

    var totalKcal: Double { restingKcal + everydayKcal + workoutKcal + cardioKcal }
}

enum DayEnergyResult: Sendable {
    case result(DayEnergyComponents)
    case missing([MissingDetail])
}

// MARK: - Core functions

private let maxWorkoutMinutes = 180.0
private let bodyFatMaxAgeDays = 90

/// Which body stats apply on `day` ("yyyy-MM-dd", local calendar).
func bodyStatsOn(day: String, weights: [BodyWeight], profile: Profile) -> BodyStats? {
    guard !weights.isEmpty else { return nil }
    let sorted = weights.sorted { $0.measuredOn < $1.measuredOn }

    // Weight: latest on or before day, else earliest after (the first entry)
    let weightEntry: BodyWeight?
    if let last = sorted.last(where: { $0.measuredOn <= day }) {
        weightEntry = last
    } else {
        weightEntry = sorted.first
    }
    guard let w = weightEntry else { return nil }

    // Body fat: same nearest rule, only entries that have body fat, within 90 days
    let withBF = sorted.filter { $0.bodyFatPct != nil }
    var bodyFatPct: Double? = nil
    let bfEntry: BodyWeight?
    if let last = withBF.last(where: { $0.measuredOn <= day }) {
        bfEntry = last
    } else {
        bfEntry = withBF.first
    }
    if let entry = bfEntry, let bf = entry.bodyFatPct {
        let dayDate   = localDateFrom(string: day) ?? .now
        let entryDate = localDateFrom(string: entry.measuredOn) ?? .distantPast
        let diffDays  = abs(Calendar.current.dateComponents([.day], from: entryDate, to: dayDate).day ?? Int.max)
        if diffDays <= bodyFatMaxAgeDays { bodyFatPct = bf }
    }

    // Age: year(day) − birth_year
    let age: Int? = profile.birthYear.flatMap { by in
        Int(day.prefix(4)).map { $0 - by }
    }

    return BodyStats(
        weightKg:      w.weightKg,
        bodyFatPct:    bodyFatPct,
        heightCm:      profile.heightCm,
        age:           age,
        sex:           profile.sex,
        dailyActivity: profile.dailyActivity,
        workoutEffort: profile.workoutEffort
    )
}

/// Resting energy (BMR) in kcal/day, or nil when inputs are insufficient.
func restingEnergy(stats: BodyStats) -> RestingEnergyResult? {
    guard stats.weightKg > 0 else { return nil }

    if let bf = stats.bodyFatPct, bf > 0, bf < 100 {
        let ffm  = stats.weightKg * (1 - bf / 100)
        let kcal = 500 + 22 * ffm
        return RestingEnergyResult(kcalPerDay: kcal, method: .cunningham(ffmKg: ffm))
    }

    guard let height = stats.heightCm, let age = stats.age else { return nil }
    let s: Double
    let explicit: Bool
    switch stats.sex {
    case .male:    s = 5;    explicit = true
    case .female:  s = -161; explicit = true
    case nil:      s = -78;  explicit = false
    }
    let kcal = max(0, 10 * stats.weightKg + 6.25 * height - 5 * Double(age) + s)
    return RestingEnergyResult(kcalPerDay: kcal, method: explicit ? .mifflin : .mifflinAverage)
}

/// Which profile details are missing to compute an estimate.
func missingDetails(stats: BodyStats?, profile: Profile) -> [MissingDetail] {
    guard let stats = stats else {
        var m: [MissingDetail] = [.weight]
        if profile.heightCm == nil  { m.append(.height) }
        if profile.birthYear == nil { m.append(.birthYear) }
        return m
    }
    if let bf = stats.bodyFatPct, bf > 0, bf < 100 { return [] }
    var m: [MissingDetail] = []
    if stats.heightCm == nil { m.append(.height) }
    if stats.age == nil      { m.append(.birthYear) }
    return m
}

/// Energy burned in a single weight-training workout above resting, in kcal.
/// `rawMinutes` should already have cardio time subtracted before passing.
func workoutEnergyFor(startedAt: Date, finishedAt: Date, stats: BodyStats) -> WorkoutEnergyResult {
    let rawMinutes     = max(0, finishedAt.timeIntervalSince(startedAt) / 60)
    let minutes        = min(rawMinutes, maxWorkoutMinutes)
    let capped         = rawMinutes > maxWorkoutMinutes
    let met            = stats.workoutEffort.met
    let restKcalPerDay = restingEnergy(stats: stats)?.kcalPerDay ?? 0
    let restKcalPerMin = restKcalPerDay / 1440
    let kcal           = netActivityKcal(met: met, minutes: minutes, weightKg: stats.weightKg, restingKcalPerDay: restKcalPerDay)
    return WorkoutEnergyResult(
        kcal:              kcal,
        minutes:           minutes,
        capped:            capped,
        met:               met,
        weightKg:          stats.weightKg,
        restingKcalPerMin: restKcalPerMin,
        effort:            stats.workoutEffort
    )
}

/// Full workout energy for a slot that may contain both sets and embedded cardio.
func estimateWorkoutEnergy(slot: WorkoutSlot, weights: [BodyWeight], profile: Profile) -> WorkoutEnergyFull? {
    guard let startedAt = Optional(slot.startedAt) else { return nil }
    let day = localDayString(from: startedAt)
    guard let stats   = bodyStatsOn(day: day, weights: weights, profile: profile),
          let resting = restingEnergy(stats: stats) else { return nil }

    let restKcalPerMin = resting.kcalPerDay / 1440
    let met            = stats.workoutEffort.met

    // Weight-training time: total minus cardio time (floored at 0, capped at 180 min)
    let cardioMin = slot.cardio.reduce(0.0) { $0 + Double($1.durationS) / 60.0 }
    let totalMin  = slot.finishedAt.map { $0.timeIntervalSince(startedAt) / 60 } ?? 0
    let pureCardio = slot.setCount == 0 && !slot.cardio.isEmpty
    let rawWeightsMin: Double = pureCardio ? 0 : max(0, totalMin - cardioMin)
    let weightsMin = min(rawWeightsMin, maxWorkoutMinutes)
    let capped     = rawWeightsMin > maxWorkoutMinutes
    let weightsKcal = netActivityKcal(met: met, minutes: weightsMin,
                                      weightKg: stats.weightKg, restingKcalPerDay: resting.kcalPerDay)

    // Per-cardio estimates
    var cardioTotalKcal = 0.0
    var cardioEstimates: [(name: String, estimate: CardioEnergyEstimate)] = []
    for row in slot.cardio {
        let est = row.energyEstimate(weights: weights, profile: profile)
        if case .result(let r) = est { cardioTotalKcal += r.kcal }
        cardioEstimates.append((name: row.exercise?.name ?? row.activity.label, estimate: est))
    }

    return WorkoutEnergyFull(
        weightsKcal:      weightsKcal,
        weightsMinutes:   weightsMin,
        weightsCapped:    capped,
        weightsMet:       met,
        weightsEffort:    stats.workoutEffort,
        cardioKcal:       cardioTotalKcal,
        cardioEstimates:  cardioEstimates,
        weightKg:         stats.weightKg,
        restingKcalPerMin: restKcalPerMin,
        restingResult:    resting
    )
}

/// Whole-day energy estimate. Workouts are `WorkoutSlot` values (which embed cardio rows).
func estimateDayEnergy(
    day:      String,
    workouts: [WorkoutSlot],
    weights:  [BodyWeight],
    profile:  Profile
) -> DayEnergyResult {
    guard let stats   = bodyStatsOn(day: day, weights: weights, profile: profile) else {
        return .missing(missingDetails(stats: nil, profile: profile))
    }
    guard let resting = restingEnergy(stats: stats) else {
        return .missing(missingDetails(stats: stats, profile: profile))
    }
    let pal             = stats.dailyActivity?.pal ?? 1.4
    let activityAssumed = stats.dailyActivity == nil
    let everydayKcal    = resting.kcalPerDay * (pal - 1)
    let met             = stats.workoutEffort.met

    var workoutKcal = 0.0
    var cardioKcal  = 0.0
    for slot in workouts where localDayString(from: slot.startedAt) == day {
        // Weight-training component
        let cardioMin  = slot.cardio.reduce(0.0) { $0 + Double($1.durationS) / 60.0 }
        let totalMin   = slot.finishedAt.map { $0.timeIntervalSince(slot.startedAt) / 60 } ?? 0
        let pureCardio = slot.setCount == 0 && !slot.cardio.isEmpty
        let rawMin: Double = pureCardio ? 0 : max(0, totalMin - cardioMin)
        let weightsMin = min(rawMin, maxWorkoutMinutes)
        workoutKcal += netActivityKcal(met: met, minutes: weightsMin,
                                       weightKg: stats.weightKg, restingKcalPerDay: resting.kcalPerDay)

        // Cardio component from embedded rows
        for row in slot.cardio {
            guard let src = cardioMet(activity: row.activity, customMet: row.exercise?.cardioMet,
                                      durationS: row.durationS, distanceM: row.distanceM,
                                      effort: row.effort) else { continue }
            let rowMet: Double
            switch src {
            case .speed(let r, _):  rowMet = r.met
            case .effort(let r, _): rowMet = r.met
            case .custom(let m):    rowMet = m
            }
            cardioKcal += netActivityKcal(
                met: rowMet, minutes: Double(row.durationS) / 60.0,
                weightKg: stats.weightKg, restingKcalPerDay: resting.kcalPerDay
            )
        }
    }

    return .result(DayEnergyComponents(
        restingKcal:     resting.kcalPerDay,
        everydayKcal:    everydayKcal,
        workoutKcal:     workoutKcal,
        cardioKcal:      cardioKcal,
        activityAssumed: activityAssumed,
        pal:             pal,
        restingResult:   resting
    ))
}

// MARK: - Rounding & formatting

private let kcalToKjFactor = 4.184

func roundKcal(_ kcal: Double) -> Int { Int((kcal / 10).rounded() * 10) }
func roundKj(_ kj: Double)   -> Int   { Int((kj   / 50).rounded() * 50) }
func kcalToKj(_ kcal: Double) -> Double { kcal * kcalToKjFactor }

func formatEnergyEstimate(_ kcal: Double, unit: EnergyUnit) -> String {
    switch unit {
    case .kj:   return "≈ \(formatThousands(roundKj(kcalToKj(kcal)))) kJ"
    case .kcal: return "≈ \(formatThousands(roundKcal(kcal))) kcal"
    }
}

func formatEnergyEstimateBoth(_ kcal: Double) -> String {
    "≈ \(formatThousands(roundKcal(kcal))) kcal (≈ \(formatThousands(roundKj(kcalToKj(kcal)))) kJ)"
}

func formatThousands(_ n: Int) -> String {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    return f.string(from: NSNumber(value: n)) ?? "\(n)"
}

// MARK: - Date helpers

func localDayString(from date: Date) -> String {
    localDayFormatter.string(from: date)
}

func localDateFrom(string s: String) -> Date? {
    localDayFormatter.date(from: s)
}

private let localDayFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    f.timeZone = .current
    return f
}()

// MARK: - Citation sources

struct EnergySource {
    let number: Int
    let citation: String
    let doi: String
}

let energySources: [EnergySource] = [
    .init(number: 1,
          citation: "Mifflin MD, St Jeor ST, Hill LA, et al. A new predictive equation for resting energy expenditure in healthy individuals. Am J Clin Nutr. 1990;51(2):241-247.",
          doi: "https://doi.org/10.1093/ajcn/51.2.241"),
    .init(number: 2,
          citation: "Frankenfield D, Roth-Yousey L, Compher C. Comparison of predictive equations for resting metabolic rate in healthy nonobese and obese adults: a systematic review. J Am Diet Assoc. 2005;105(5):775-789.",
          doi: "https://doi.org/10.1016/j.jada.2005.02.005"),
    .init(number: 3,
          citation: "Cunningham JJ. A reanalysis of the factors influencing basal metabolic rate in normal adults. Am J Clin Nutr. 1980;33(11):2372-2374.",
          doi: "https://doi.org/10.1093/ajcn/33.11.2372"),
    .init(number: 4,
          citation: "ten Haaf T, Weijs PJM. Resting energy expenditure prediction in recreational athletes of 18-35 years: confirmation of Cunningham equation and an improved weight-based alternative. PLoS One. 2014;9(10):e108460.",
          doi: "https://doi.org/10.1371/journal.pone.0108460"),
    .init(number: 5,
          citation: "Herrmann SD, Willis EA, Ainsworth BE, et al. 2024 Adult Compendium of Physical Activities: a third update of the energy costs of human activities. J Sport Health Sci. 2024;13(1):6-12.",
          doi: "https://doi.org/10.1016/j.jshs.2023.10.010"),
    .init(number: 6,
          citation: "FAO/WHO/UNU. Human energy requirements: report of a joint FAO/WHO/UNU expert consultation. FAO Food and Nutrition Technical Report Series 1. Rome; 2004.",
          doi: "https://www.fao.org/4/y5686e/y5686e00.htm"),
]
