import SwiftUI

/// Top-level container. Routes to Set / Rest / Summary based on `activeWorkout.phase`.
struct WorkoutPlayerView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if let workout = appState.activeWorkout {
                switch workout.phase {
                case .set:
                    SetScreenView()
                case .rest:
                    RestScreenView()
                case .complete:
                    SummaryScreenView(workout: workout)
                }
            }
        }
        .background(Color.ssBackground)
        .preferredColorScheme(.dark)
    }
}
