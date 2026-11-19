import SwiftUI

/// Top-level container. Routes to Cardio / Set / Rest / Summary based on `activeWorkout.phase`.
struct WorkoutPlayerView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if let workout = appState.activeWorkout {
                switch workout.phase {
                case .set:
                    if workout.currentExercise?.isCardio == true {
                        CardioStartView()
                    } else {
                        SetScreenView()
                    }
                case .rest:
                    RestScreenView()
                case .cardio(let timer):
                    if timer.hasEnded {
                        CardioLogView()
                    } else {
                        CardioTimerView()
                    }
                case .complete:
                    SummaryScreenView(workout: workout)
                }
            }
        }
        .background(Color.ssBackground)
        .preferredColorScheme(.dark)
    }
}
