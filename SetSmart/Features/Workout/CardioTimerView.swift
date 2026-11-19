import SwiftUI

struct CardioTimerView: View {
    @Environment(AppState.self) private var appState
    @State private var showDiscard = false

    private var workout: WorkoutState? { appState.activeWorkout }

    private var timer: CardioTimer? {
        guard let w = workout, case .cardio(let t) = w.phase else { return nil }
        return t
    }

    private var exercise: WorkoutExercise? {
        guard let t = timer, let w = workout else { return nil }
        return w.exercises[t.exerciseIndex]
    }

    private var plan: CardioPlan? { exercise?.cardio }

    var body: some View {
        NavigationStack {
            if let workout = appState.activeWorkout, timer != nil {
                TimelineView(.periodic(from: .now, by: 1)) { ctx in
                    let elapsedS = Int(workout.cardioElapsed(now: ctx.date) / 1000)
                    scrollContent(elapsedS: elapsedS, workout: workout)
                }
                .background(Color.ssBackground.ignoresSafeArea())
                .navigationTitle(workout.name)
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        .confirmationDialog("Discard timer?", isPresented: $showDiscard, titleVisibility: .visible) {
            Button("Discard timer", role: .destructive) {
                appState.applyWorkoutAction(.cancelCardio)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your progress for this exercise won't be saved.")
        }
    }

    @ViewBuilder
    private func scrollContent(elapsedS: Int, workout: WorkoutState) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                Text(exercise?.name ?? "")
                    .font(.subheadline)
                    .foregroundStyle(Color.ssTextSecondary)
                    .padding(.top, 24)

                timerRing(elapsedS: elapsedS)
                    .padding(.vertical, 32)

                controls
                    .padding(.horizontal, 24)

                Button { showDiscard = true } label: {
                    Text("Discard timer")
                        .font(.subheadline)
                        .foregroundStyle(Color.ssDanger)
                }
                .padding(.top, 20)

                if workout.queue.count >= 2 {
                    laterQueue(workout: workout)
                        .padding(.top, 28)
                }

                Spacer(minLength: 32)
            }
        }
    }

    @ViewBuilder
    private func timerRing(elapsedS: Int) -> some View {
        let goalS    = plan?.targetDurationS ?? 0
        let progress = goalS > 0 ? min(1.0, Double(elapsedS) / Double(goalS)) : 0.0
        let reached  = goalS > 0 && elapsedS >= goalS

        ZStack {
            Circle()
                .stroke(Color.ssSurface, lineWidth: 14)
                .frame(width: 220, height: 220)

            if goalS > 0 {
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        reached ? Color.ssWarning : Color.ssAccent,
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 220, height: 220)
                    .animation(.linear(duration: 0.4), value: progress)
            }

            VStack(spacing: 6) {
                Text(formatElapsed(elapsedS))
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.ssTextPrimary)

                Text(statusLabel(elapsedS: elapsedS, reached: reached))
                    .font(.caption.weight(.semibold))
                    .tracking(1)
                    .foregroundStyle(
                        reached
                            ? Color.ssWarningText
                            : (timer?.isRunning == true ? Color.ssTextMuted : Color.ssAccent)
                    )
            }
        }
    }

    @ViewBuilder
    private var controls: some View {
        HStack(spacing: 12) {
            if timer?.isRunning == true {
                Button { appState.applyWorkoutAction(.pauseCardio) } label: {
                    Label("Pause", systemImage: "pause.fill")
                }
                .buttonStyle(SecondaryButtonStyle())
            } else {
                Button { appState.applyWorkoutAction(.resumeCardio) } label: {
                    Label("Resume", systemImage: "play.fill")
                }
                .buttonStyle(SecondaryButtonStyle())
            }

            Button { appState.applyWorkoutAction(.endCardio) } label: {
                Text("End")
            }
            .buttonStyle(PrimaryButtonStyle())
        }
    }

    private func laterQueue(workout: WorkoutState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("LATER")
                .font(.caption.weight(.semibold))
                .tracking(1)
                .foregroundStyle(Color.ssTextMuted)
                .padding(.horizontal, 24)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(workout.queue.dropFirst(), id: \.self) { idx in
                        Text(workout.exercises[idx].name)
                            .font(.caption)
                            .foregroundStyle(Color.ssTextSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Color.ssSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }

    private func formatElapsed(_ totalS: Int) -> String {
        let h = totalS / 3600
        let m = (totalS % 3600) / 60
        let s = totalS % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }

    private func statusLabel(elapsedS: Int, reached: Bool) -> String {
        if timer?.isRunning != true { return "PAUSED" }
        if reached { return "GOAL REACHED!" }
        if let goalS = plan?.targetDurationS, goalS > 0 {
            let remaining = goalS - elapsedS
            let m = remaining / 60; let s = remaining % 60
            return String(format: "%d:%02d left", m, s)
        }
        return "RUNNING"
    }
}
