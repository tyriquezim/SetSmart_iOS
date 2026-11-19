import SwiftUI

struct CardioStartView: View {
    @Environment(AppState.self) private var appState
    @State private var showSkipConfirm = false

    private var workout: WorkoutState?         { appState.activeWorkout }
    private var exercise: WorkoutExercise?     { workout?.currentExercise }
    private var plan: CardioPlan?              { exercise?.cardio }
    private var nextExercise: WorkoutExercise? { workout?.nextQueueExercise }
    private var canPostpone: Bool              { workout?.canPostpone ?? false }

    var body: some View {
        NavigationStack {
            // Guard: phase/queue may change while this view is still in the hierarchy
            if let workout = appState.activeWorkout, let exercise, let plan {
                VStack(spacing: 0) {
                    Spacer()

                    VStack(spacing: 28) {
                        Image(systemName: plan.activity.systemImage)
                            .font(.system(size: 48))
                            .foregroundStyle(Color.ssAccent)

                        VStack(spacing: 10) {
                            Text("CARDIO")
                                .font(.caption.weight(.bold))
                                .tracking(2)
                                .foregroundStyle(Color.ssAccent)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 5)
                                .background(Color.ssAccent.opacity(0.15))
                                .clipShape(Capsule())

                            Text(exercise.name)
                                .font(.title2.weight(.bold))
                                .foregroundStyle(Color.ssTextPrimary)
                                .multilineTextAlignment(.center)

                            if let goal = goalText {
                                Label("Goal: \(goal)", systemImage: "flag.fill")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.ssTextSecondary)
                            } else {
                                Label("No goal set", systemImage: "flag")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.ssTextMuted)
                            }
                        }

                        Button {
                            appState.applyWorkoutAction(.startCardio)
                        } label: {
                            Label("Start", systemImage: "play.fill")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .padding(.horizontal, 32)
                    }

                    Spacer()

                    VStack(spacing: 16) {
                        if canPostpone, let next = nextExercise {
                            Button {
                                appState.applyWorkoutAction(.postpone(.next))
                            } label: {
                                Text("Not now? Do \(next.name) first")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.ssAccent)
                            }
                        }

                        Button { showSkipConfirm = true } label: {
                            Text("Skip this exercise")
                                .font(.subheadline)
                                .foregroundStyle(Color.ssTextMuted)
                        }
                    }
                    .padding(.bottom, 36)
                }
                .padding(.horizontal, 24)
                .background(Color.ssBackground.ignoresSafeArea())
                .navigationTitle(workout.name)
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        .confirmationDialog("Skip exercise?", isPresented: $showSkipConfirm, titleVisibility: .visible) {
            Button("Skip \(exercise?.name ?? "exercise")", role: .destructive) {
                appState.applyWorkoutAction(.skipExercise)
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var goalText: String? {
        guard let s = plan?.targetDurationS, s > 0 else { return nil }
        let min = s / 60
        if min >= 60 {
            let h = min / 60; let m = min % 60
            return m == 0 ? "\(h) h" : "\(h) h \(m) min"
        }
        return "\(min) min"
    }
}
