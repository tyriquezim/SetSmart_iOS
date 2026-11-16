import Foundation

// MARK: - Epley 1RM

extension WorkoutState {
    static func epley(weight: Double, reps: Int) -> Double? {
        guard weight > 0, reps >= 1, reps <= 12 else { return nil }
        if reps == 1 { return weight }
        return weight * (1 + Double(reps) / 30)
    }
}

// MARK: - Selectors

extension WorkoutState {

    var currentSet: CurrentSetInfo? {
        guard case .set = phase, let idx = queue.first else { return nil }
        let ex = exercises[idx]
        let setNumber  = ex.logged.count + 1
        let totalSets  = ex.sets.count
        let targetIdx  = min(ex.logged.count, max(0, ex.sets.count - 1))
        let target     = ex.sets.isEmpty
            ? PlannedSet(reps: 10, weightKg: nil)
            : ex.sets[targetIdx]
        let previous   = ex.logged.last
        let lastTime: LastSet? = {
            guard let h = ex.history else { return nil }
            let i = min(ex.logged.count, max(0, h.lastSets.count - 1))
            return h.lastSets.isEmpty ? nil : h.lastSets[i]
        }()

        return CurrentSetInfo(
            exerciseName:    ex.name,
            setNumber:       setNumber,
            totalSets:       totalSets,
            targetReps:      target.reps,
            targetWeightKg:  target.weightKg,
            previousReps:    previous?.reps,
            previousWeightKg: previous?.weightKg,
            lastTimeReps:    lastTime?.reps,
            lastTimeWeightKg: lastTime?.weightKg,
            prefillReps:     previous?.reps ?? target.reps,
            prefillWeightKg: previous?.weightKg ?? target.weightKg ?? lastTime?.weightKg
        )
    }

    var nextSetInfo: CurrentSetInfo? {
        guard queue.count >= 2 else { return nil }
        let idx = queue[1]
        let ex  = exercises[idx]
        let setNumber  = ex.logged.count + 1
        let totalSets  = ex.sets.count
        let targetIdx  = min(ex.logged.count, max(0, ex.sets.count - 1))
        let target     = ex.sets.isEmpty ? PlannedSet(reps: 10, weightKg: nil) : ex.sets[targetIdx]
        let previous   = ex.logged.last
        let lastTime: LastSet? = {
            guard let h = ex.history else { return nil }
            let i = min(ex.logged.count, max(0, h.lastSets.count - 1))
            return h.lastSets.isEmpty ? nil : h.lastSets[i]
        }()
        return CurrentSetInfo(
            exerciseName:    ex.name,
            setNumber:       setNumber,
            totalSets:       totalSets,
            targetReps:      target.reps,
            targetWeightKg:  target.weightKg,
            previousReps:    previous?.reps,
            previousWeightKg: previous?.weightKg,
            lastTimeReps:    lastTime?.reps,
            lastTimeWeightKg: lastTime?.weightKg,
            prefillReps:     previous?.reps ?? target.reps,
            prefillWeightKg: previous?.weightKg ?? target.weightKg ?? lastTime?.weightKg
        )
    }

    var restRemaining: TimeInterval? {
        guard case .rest(_, let endsAt) = phase else { return nil }
        return endsAt.timeIntervalSinceNow
    }

    var canPostpone: Bool {
        phase != .complete && queue.count >= 2
    }

    var totals: WorkoutTotals {
        WorkoutTotals(
            setsLogged:    exercises.reduce(0) { $0 + $1.logged.count },
            setsPlanned:   exercises.reduce(0) { $0 + $1.sets.count },
            volumeKg:      exercises.reduce(0) { $0 + $1.logged.reduce(0) { $0 + Double($1.reps) * ($1.weightKg ?? 0) } },
            exercisesDone: exercises.filter { $0.status == .done }.count
        )
    }

    /// PR flags per exercise. Only exercises with history can get a PR.
    var prs: [UUID: PRResult] {
        var result: [UUID: PRResult] = [:]
        for ex in exercises {
            guard let history = ex.history else { continue }
            let bestE1rm    = ex.logged.compactMap { s -> Double? in
                guard let w = s.weightKg else { return nil }
                return WorkoutState.epley(weight: w, reps: s.reps)
            }.max()
            let heaviest    = ex.logged.filter { $0.reps > 0 }.compactMap { $0.weightKg }.max()
            let e1rmPR      = (bestE1rm ?? 0)   > (history.bestE1rmKg  ?? 0) + 0.01
            let weightPR    = (heaviest ?? 0)    > (history.maxWeightKg ?? 0) + 0.01
            if e1rmPR || weightPR {
                result[ex.exerciseId] = PRResult(e1rmPR: e1rmPR, weightPR: weightPR)
            }
        }
        return result
    }
}
