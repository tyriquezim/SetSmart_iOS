import Foundation

extension WorkoutState {
    mutating func apply(_ action: WorkoutAction, now: Date) {
        switch action {

        case .logSet(let reps, let weightKg):
            guard case .set = phase, !queue.isEmpty else { return }
            let idx = queue[0]
            var ex  = exercises[idx]

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

            // Mark done and remove from queue only when all sets are finished.
            if ex.logged.count >= ex.sets.count {
                ex.status = .done
                queue.removeFirst()
            }
            exercises[idx] = ex

            // Rest starts after every logged set, not only when an exercise is fully done.
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
            guard phase != .complete, queue.count >= 2 else { return }
            switch mode {
            case .next: queue.swapAt(0, 1)
            case .end:  queue.append(queue.removeFirst())
            }

        case .skipExercise:
            guard !queue.isEmpty else { return }
            let idx = queue[0]
            exercises[idx].status = exercises[idx].logged.isEmpty ? .skipped : .done
            queue.removeFirst()
            if queue.isEmpty {
                phase      = .complete
                finishedAt = now
            } else if case .rest = phase {
                phase = .set
            }

        case .addSet:
            guard !queue.isEmpty else { return }
            let idx  = queue[0]
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
        }
    }
}
