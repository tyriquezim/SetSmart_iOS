import Foundation

extension WorkoutState {
    mutating func apply(_ action: WorkoutAction, now: Date) {
        switch action {

        case .logSet(let reps, let weightKg):
            guard case .set = phase, !queue.isEmpty else { return }
            let idx = queue[0]
            var ex  = exercises[idx]
            guard !ex.isCardio else { return }  // ignored for cardio

            let targetIdx = ex.sets.isEmpty ? 0 : min(ex.logged.count, ex.sets.count - 1)
            let target    = ex.sets.isEmpty
                ? PlannedSet(reps: 10, weightKg: nil)
                : ex.sets[targetIdx]

            ex.logged.append(LoggedSet(
                reps:            max(0, reps),
                weightKg:        weightKg.map { max(0, $0) },
                targetReps:      target.reps,
                targetWeightKg:  target.weightKg,
                completedAt:     now
            ))

            if !performedOrder.contains(idx) {
                performedOrder.append(idx)
            }

            if ex.logged.count >= ex.sets.count {
                ex.status = .done
                queue.removeFirst()
            }
            exercises[idx] = ex

            if queue.isEmpty {
                phase      = .complete
                finishedAt = now
            } else if ex.restSeconds <= 0 {
                phase = .set
            } else {
                phase = .rest(
                    startedAt: now,
                    endsAt:    now.addingTimeInterval(Double(ex.restSeconds))
                )
            }

        case .endRest:
            guard case .rest = phase else { return }
            phase = .set

        case .adjustRest(let delta):
            guard case .rest(let s, let e) = phase else { return }
            phase = .rest(startedAt: s, endsAt: max(now, e.addingTimeInterval(Double(delta))))

        case .postpone(let mode):
            guard !phase.isCardio, phase != .complete, queue.count >= 2 else { return }
            switch mode {
            case .next: queue.swapAt(0, 1)
            case .end:  queue.append(queue.removeFirst())
            }

        case .skipExercise:
            guard !queue.isEmpty else { return }
            let idx = queue[0]
            exercises[idx].status = exercises[idx].logged.isEmpty && exercises[idx].cardioLog == nil
                ? .skipped : .done
            queue.removeFirst()
            if case .cardio = phase { phase = .set }
            if queue.isEmpty {
                phase      = .complete
                finishedAt = now
            } else if case .rest = phase {
                phase = .set
            }

        case .addSet:
            guard !queue.isEmpty else { return }
            let idx  = queue[0]
            guard !exercises[idx].isCardio else { return }
            let last = exercises[idx].sets.last ?? PlannedSet(reps: 10, weightKg: nil)
            exercises[idx].sets.append(last)

        case .editLoggedSet(let eIdx, let sIdx, let reps, let weightKg):
            guard eIdx < exercises.count, sIdx < exercises[eIdx].logged.count else { return }
            exercises[eIdx].logged[sIdx].reps     = max(0, reps)
            exercises[eIdx].logged[sIdx].weightKg = weightKg.map { max(0, $0) }

        case .finish:
            guard phase != .complete else { return }
            phase      = .complete
            finishedAt = now

        case .reopen:
            guard phase == .complete, !queue.isEmpty else { return }
            phase      = .set
            finishedAt = nil

        // MARK: - Cardio timer actions

        case .startCardio:
            guard case .set = phase, !queue.isEmpty else { return }
            let idx = queue[0]
            guard exercises[idx].isCardio else { return }
            phase = .cardio(CardioTimer(
                exerciseIndex: idx,
                startedAt:     now,
                accumulatedMs: 0,
                runningSince:  now,
                endedAt:       nil
            ))

        case .pauseCardio:
            guard case .cardio(var t) = phase, t.isRunning else { return }
            t.accumulatedMs += now.timeIntervalSince(t.runningSince!) * 1000
            t.runningSince   = nil
            phase = .cardio(t)

        case .resumeCardio:
            guard case .cardio(var t) = phase, !t.isRunning else { return }
            t.runningSince = now
            t.endedAt      = nil
            phase = .cardio(t)

        case .endCardio:
            guard case .cardio(var t) = phase, !t.hasEnded else { return }
            if let rs = t.runningSince {
                t.accumulatedMs += now.timeIntervalSince(rs) * 1000
            }
            t.runningSince = nil
            t.endedAt      = now
            phase = .cardio(t)

        case .cancelCardio:
            guard case .cardio = phase else { return }
            phase = .set

        case .logCardio(let durationS, let distanceM, let effort):
            guard case .cardio(let t) = phase, t.hasEnded else { return }
            let idx = t.exerciseIndex
            guard idx < exercises.count else { return }
            let clampedDuration = max(1, min(86400, durationS))
            exercises[idx].cardioLog = LoggedCardio(
                startedAt:   t.startedAt,
                durationS:   clampedDuration,
                distanceM:   distanceM.flatMap { $0 > 0 ? $0 : nil },
                effort:      effort,
                completedAt: now
            )
            exercises[idx].status = .done
            queue.removeFirst()
            if !performedOrder.contains(idx) {
                performedOrder.append(idx)
            }
            if queue.isEmpty {
                phase      = .complete
                finishedAt = now
            } else {
                phase = .set  // no rest after cardio
            }
        }
    }
}

