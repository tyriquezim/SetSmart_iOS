import Testing
@testable import SetSmart

// MARK: - Helpers

private func makeRoutine(restSeconds: Int = 60, sets: [PlannedSet]? = nil) -> Routine {
    let plannedSets = sets ?? [PlannedSet(reps: 8, weightKg: 100)]
    let ex = RoutineExercise(
        id: 1,
        position: 0,
        exerciseId: UUID(),
        notes: nil,
        restSeconds: restSeconds,
        sets: plannedSets,
        exercise: Exercise(
            id: UUID(), name: "Bench Press", muscleGroup: .chest,
            equipment: .barbell, notes: nil, ownerId: nil, archivedAt: nil
        )
    )
    return Routine(
        id: UUID(), name: "Test Routine", notes: nil, updatedAt: .now,
        routineExercises: [ex]
    )
}

private let t0 = Date(timeIntervalSince1970: 0)

// MARK: - Engine tests

@Suite("WorkoutEngine")
struct WorkoutEngineTests {

    @Test("logSet advances to rest phase with correct endsAt")
    func logSetStartsRest() {
        var state = WorkoutState.create(from: makeRoutine(restSeconds: 90), now: t0)
        state.apply(.logSet(reps: 8, weightKg: 100), now: t0)

        if case .rest(let startedAt, let endsAt) = state.phase {
            #expect(startedAt == t0)
            #expect(endsAt == t0.addingTimeInterval(90))
        } else {
            Issue.record("Expected rest phase, got \(state.phase)")
        }
    }

    @Test("endRest returns to set phase")
    func endRestGoesToSet() {
        var state = WorkoutState.create(from: makeRoutine(restSeconds: 60), now: t0)
        state.apply(.logSet(reps: 8, weightKg: 100), now: t0)
        state.apply(.endRest, now: t0)
        if case .complete = state.phase {
            // Single set, one exercise → complete is correct
        } else if case .set = state.phase {
            // Multi-set exercise
        } else {
            Issue.record("Unexpected phase after endRest: \(state.phase)")
        }
    }

    @Test("adjustRest adds time correctly")
    func adjustRestAdds() {
        var state = WorkoutState.create(from: makeRoutine(restSeconds: 60), now: t0)
        state.apply(.logSet(reps: 8, weightKg: 100), now: t0)

        guard case .rest(_, let before) = state.phase else {
            Issue.record("Not in rest phase"); return
        }
        state.apply(.adjustRest(deltaSeconds: 15), now: t0)
        guard case .rest(_, let after) = state.phase else {
            Issue.record("Not in rest phase after adjust"); return
        }
        #expect(after == before.addingTimeInterval(15))
    }

    @Test("adjustRest cannot make endsAt go before now")
    func adjustRestNoNegative() {
        var state = WorkoutState.create(from: makeRoutine(restSeconds: 60), now: t0)
        state.apply(.logSet(reps: 8, weightKg: 100), now: t0)
        state.apply(.adjustRest(deltaSeconds: -999), now: t0)
        if case .rest(_, let endsAt) = state.phase {
            #expect(endsAt >= t0)
        }
    }

    @Test("skipExercise clears rest and completes single-exercise workout")
    func skipExerciseFromRest() {
        var state = WorkoutState.create(from: makeRoutine(restSeconds: 60), now: t0)
        state.apply(.logSet(reps: 8, weightKg: 100), now: t0)
        guard case .rest = state.phase else { Issue.record("Expected rest"); return }
        state.apply(.skipExercise, now: t0)
        if case .complete = state.phase {} else {
            Issue.record("Expected complete, got \(state.phase)")
        }
    }

    @Test("workout completes after all sets logged (restSeconds == 0)")
    func completesAfterAllSets() {
        let routine = makeRoutine(restSeconds: 0, sets: [
            PlannedSet(reps: 8, weightKg: 100),
            PlannedSet(reps: 8, weightKg: 100)
        ])
        var state = WorkoutState.create(from: routine, now: t0)
        state.apply(.logSet(reps: 8, weightKg: 100), now: t0)   // set 1 → phase .set (rest=0)
        state.apply(.logSet(reps: 8, weightKg: 100), now: t0)   // set 2 → complete

        if case .complete = state.phase {} else {
            Issue.record("Expected complete after all sets, got \(state.phase)")
        }
    }
}

// MARK: - Selector / Epley tests

@Suite("WorkoutSelectors")
struct WorkoutSelectorTests {

    @Test("epley: returns nil for reps > 12")
    func epleyNilAbove12() {
        #expect(WorkoutState.epley(weight: 100, reps: 13) == nil)
    }

    @Test("epley: returns weight when reps == 1")
    func epleyOneRep() {
        #expect(WorkoutState.epley(weight: 100, reps: 1) == 100)
    }

    @Test("epley: returns nil when weight <= 0")
    func epleyZeroWeight() {
        #expect(WorkoutState.epley(weight: 0, reps: 5) == nil)
    }

    @Test("epley: returns nil when reps < 1")
    func epleyZeroReps() {
        #expect(WorkoutState.epley(weight: 100, reps: 0) == nil)
    }

    @Test("epley: formula correct for 10 reps at 100 kg")
    func epleyFormula() {
        let result   = WorkoutState.epley(weight: 100, reps: 10)
        let expected = 100 * (1 + 10.0 / 30)   // ≈ 133.33
        #expect(abs((result ?? 0) - expected) < 0.001)
    }
}

// MARK: - EnergyEstimates tests

@Suite("EnergyEstimates")
struct EnergyEstimatesTests {

    // MARK: Helpers

    private func makeProfile(
        heightCm: Double? = 180,
        birthYear: Int? = 1999,
        sex: Sex? = .male,
        dailyActivity: DailyActivity? = .sitting,
        workoutEffort: WorkoutEffort = .moderate
    ) -> Profile {
        Profile(
            id: UUID(), displayName: nil,
            weightUnit: .kg, energyUnit: .kj,
            heightCm: heightCm, birthYear: birthYear,
            sex: sex, dailyActivity: dailyActivity,
            workoutEffort: workoutEffort
        )
    }

    private func bw(_ day: String, kg: Double, bf: Double? = nil) -> BodyWeight {
        BodyWeight(id: UUID(), measuredOn: day, weightKg: kg, bodyFatPct: bf, note: nil)
    }

    // MARK: - Mifflin-St Jeor

    @Test("Mifflin male: 80 kg, 180 cm, 25 yr → 1805 kcal")
    func mifflinMale() {
        let stats = BodyStats(
            weightKg: 80, bodyFatPct: nil, heightCm: 180, age: 25,
            sex: .male, dailyActivity: .sitting, workoutEffort: .moderate
        )
        let r = restingEnergy(stats: stats)
        #expect(r?.method == .mifflin)
        // 10×80 + 6.25×180 − 5×25 + 5 = 1805
        #expect(abs((r?.kcalPerDay ?? 0) - 1805) < 0.01)
    }

    @Test("Mifflin female: 65 kg, 165 cm, 30 yr → 1370.25 kcal")
    func mifflinFemale() {
        let stats = BodyStats(
            weightKg: 65, bodyFatPct: nil, heightCm: 165, age: 30,
            sex: .female, dailyActivity: nil, workoutEffort: .moderate
        )
        let r = restingEnergy(stats: stats)
        #expect(r?.method == .mifflin)
        // 10×65 + 6.25×165 − 5×30 − 161 = 1370.25
        #expect(abs((r?.kcalPerDay ?? 0) - 1370.25) < 0.01)
    }

    @Test("Mifflin average (no sex): 80 kg, 180 cm, 25 yr → 1722 kcal")
    func mifflinAverage() {
        let stats = BodyStats(
            weightKg: 80, bodyFatPct: nil, heightCm: 180, age: 25,
            sex: nil, dailyActivity: nil, workoutEffort: .moderate
        )
        let r = restingEnergy(stats: stats)
        #expect(r?.method == .mifflinAverage)
        // 10×80 + 6.25×180 − 5×25 − 78 = 1722
        #expect(abs((r?.kcalPerDay ?? 0) - 1722) < 0.01)
    }

    // MARK: - Cunningham

    @Test("Cunningham: 80 kg, 15% BF → FFM 68 kg, 1996 kcal")
    func cunningham() {
        let stats = BodyStats(
            weightKg: 80, bodyFatPct: 15, heightCm: nil, age: nil,
            sex: nil, dailyActivity: nil, workoutEffort: .moderate
        )
        let r = restingEnergy(stats: stats)
        guard let method = r?.method, case .cunningham(let ffm) = method else {
            Issue.record("Expected .cunningham method"); return
        }
        // FFM = 80 × 0.85 = 68
        #expect(abs(ffm - 68) < 0.001)
        // 500 + 22 × 68 = 1996
        #expect(abs((r?.kcalPerDay ?? 0) - 1996) < 0.01)
    }

    @Test("Cunningham preferred over Mifflin when body fat is set")
    func cunninghamPreferredOverMifflin() {
        let stats = BodyStats(
            weightKg: 80, bodyFatPct: 15, heightCm: 180, age: 25,
            sex: .male, dailyActivity: nil, workoutEffort: .moderate
        )
        let r = restingEnergy(stats: stats)
        if case .cunningham = r?.method {} else {
            Issue.record("Expected Cunningham when both BF and height/age are set")
        }
    }

    // MARK: - bodyStatsOn

    @Test("bodyStatsOn: nearest weight on or before day")
    func bodyStatsOnWeight() {
        let weights = [bw("2024-01-01", kg: 80), bw("2024-01-15", kg: 82)]
        let profile = makeProfile()
        #expect(bodyStatsOn(day: "2024-01-10", weights: weights, profile: profile)?.weightKg == 80)
        #expect(bodyStatsOn(day: "2024-01-15", weights: weights, profile: profile)?.weightKg == 82)
    }

    @Test("bodyStatsOn: falls back to first entry when day is before all weights")
    func bodyStatsOnFallback() {
        let weights = [bw("2024-02-01", kg: 75)]
        let profile = makeProfile()
        #expect(bodyStatsOn(day: "2024-01-01", weights: weights, profile: profile)?.weightKg == 75)
    }

    @Test("bodyStatsOn: returns nil with empty weight list")
    func bodyStatsOnEmpty() {
        #expect(bodyStatsOn(day: "2024-01-01", weights: [], profile: makeProfile()) == nil)
    }

    @Test("bodyStatsOn: includes body fat within 90 days")
    func bodyStatsOnBodyFatWithin90() {
        let weights = [bw("2024-01-10", kg: 80, bf: 15)]
        let profile = makeProfile()
        // 10 days after → within 90-day window
        #expect(bodyStatsOn(day: "2024-01-20", weights: weights, profile: profile)?.bodyFatPct == 15)
    }

    @Test("bodyStatsOn: excludes body fat beyond 90 days")
    func bodyStatsOnBodyFatBeyond90() {
        let weights = [bw("2024-01-01", kg: 80, bf: 15)]
        let profile = makeProfile()
        // 92 days after (Jan 1 → Apr 2, 2024 is a leap year) → beyond 90-day window
        #expect(bodyStatsOn(day: "2024-04-02", weights: weights, profile: profile)?.bodyFatPct == nil)
    }

    // MARK: - Workout energy

    @Test("workoutEnergyFor: 60 min moderate, 80 kg male → energy above resting")
    func workoutEnergyAboveResting() {
        let stats = BodyStats(
            weightKg: 80, bodyFatPct: nil, heightCm: 180, age: 25,
            sex: .male, dailyActivity: .sitting, workoutEffort: .moderate
        )
        let start = Date(timeIntervalSince1970: 0)
        let r = workoutEnergyFor(startedAt: start, finishedAt: start.addingTimeInterval(3600), stats: stats)
        #expect(r.minutes == 60)
        #expect(!r.capped)
        // gross = 3.5 × 3.5 × 80 / 200 = 4.9 kcal/min; resting = 1805/1440 ≈ 1.253
        // net = (4.9 − 1.253) × 60 ≈ 218.8
        #expect(abs(r.kcal - 218.79) < 1.0)
    }

    @Test("workoutEnergyFor: caps at 180 minutes")
    func workoutEnergyCapped() {
        let stats = BodyStats(
            weightKg: 80, bodyFatPct: nil, heightCm: 180, age: 25,
            sex: .male, dailyActivity: nil, workoutEffort: .moderate
        )
        let start = Date(timeIntervalSince1970: 0)
        let r = workoutEnergyFor(startedAt: start, finishedAt: start.addingTimeInterval(200 * 60), stats: stats)
        #expect(r.minutes == 180)
        #expect(r.capped)
    }

    // MARK: - Day totals

    @Test("estimateDayEnergy: totalKcal equals sum of components")
    func dayEnergyTotal() {
        let weights = [bw("2024-06-01", kg: 80)]
        let profile = makeProfile(birthYear: 1999, sex: .male, dailyActivity: .sitting)
        let result = estimateDayEnergy(day: "2024-06-01", workouts: [], weights: weights, profile: profile)
        guard case .result(let c) = result else {
            Issue.record("Expected .result, got missing"); return
        }
        #expect(abs(c.totalKcal - (c.restingKcal + c.everydayKcal + c.workoutKcal)) < 0.001)
    }

    @Test("estimateDayEnergy: .missing(.weight) when no weights")
    func dayEnergyMissingWeight() {
        let result = estimateDayEnergy(day: "2024-01-01", workouts: [], weights: [], profile: makeProfile())
        guard case .missing(let m) = result else {
            Issue.record("Expected .missing"); return
        }
        #expect(m.contains(.weight))
    }

    @Test("estimateDayEnergy: .missing when no height/birthYear and no body fat")
    func dayEnergyMissingHeight() {
        let weights = [bw("2024-01-01", kg: 80)]
        let profile = makeProfile(heightCm: nil, birthYear: nil, sex: nil)
        let result = estimateDayEnergy(day: "2024-01-01", workouts: [], weights: weights, profile: profile)
        guard case .missing(let m) = result else {
            Issue.record("Expected .missing"); return
        }
        #expect(m.contains(.height) || m.contains(.birthYear))
    }

    @Test("estimateDayEnergy: succeeds with Cunningham even without height/birthYear")
    func dayEnergySucceedsWithCunningham() {
        let weights = [bw("2024-01-01", kg: 80, bf: 15)]
        let profile = makeProfile(heightCm: nil, birthYear: nil, sex: nil)
        let result = estimateDayEnergy(day: "2024-01-01", workouts: [], weights: weights, profile: profile)
        if case .missing = result {
            Issue.record("Should succeed with Cunningham even without height/birthYear")
        }
    }

    // MARK: - Rounding

    @Test("roundKcal rounds to nearest 10")
    func roundKcalTest() {
        #expect(roundKcal(1054) == 1050)
        #expect(roundKcal(1055) == 1060)
        #expect(roundKcal(1060) == 1060)
        #expect(roundKcal(1001) == 1000)
    }

    @Test("roundKj rounds to nearest 50")
    func roundKjTest() {
        #expect(roundKj(1024) == 1000)
        #expect(roundKj(1025) == 1050)
        #expect(roundKj(1050) == 1050)
        #expect(roundKj(1076) == 1100)
    }

    @Test("kcalToKj uses factor 4.184")
    func kcalToKjConversion() {
        #expect(abs(kcalToKj(100) - 418.4) < 0.001)
    }
}

// MARK: - FlexDouble tests

@Suite("FlexDouble")
struct FlexDoubleTests {

    @Test("decodes from JSON number")
    func fromNumber() throws {
        struct Wrapper: Codable { var v: FlexDouble }
        let json = #"{"v": 3.14}"#.data(using: .utf8)!
        let w = try JSONDecoder().decode(Wrapper.self, from: json)
        #expect(abs((w.v.value ?? 0) - 3.14) < 0.001)
    }

    @Test("decodes from JSON string")
    func fromString() throws {
        struct Wrapper: Codable { var v: FlexDouble }
        let json = #"{"v": "2.72"}"#.data(using: .utf8)!
        let w = try JSONDecoder().decode(Wrapper.self, from: json)
        #expect(abs((w.v.value ?? 0) - 2.72) < 0.001)
    }
}
