import SwiftUI

struct MainTabView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState
        TabView(selection: $state.selectedTab) {
            HomeView()
                .tabItem { Label("Home",     systemImage: "house.fill") }
                .tag(0)

            RoutinesView()
                .tabItem { Label("Routines", systemImage: "list.bullet.rectangle.fill") }
                .tag(1)

            FoodView()
                .tabItem { Label("Food",     systemImage: "fork.knife") }
                .tag(2)

            ProgressTabView()
                .tabItem { Label("Progress", systemImage: "chart.xyaxis.line") }
                .tag(3)

            HistoryView()
                .tabItem { Label("History",  systemImage: "clock.fill") }
                .tag(4)
        }
        .tint(Color.ssAccent)
        .overlay(alignment: .top) {
            if appState.activeWorkout != nil, !appState.isWorkoutPlayerVisible {
                ResumeBanner()
            }
        }
        .fullScreenCover(isPresented: $state.isWorkoutPlayerVisible) {
            if appState.activeWorkout != nil {
                WorkoutPlayerView()
            }
        }
    }
}

private struct ResumeBanner: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Button {
            appState.isWorkoutPlayerVisible = true
        } label: {
            HStack {
                Image(systemName: "dumbbell.fill")
                    .foregroundStyle(Color.ssAccent)
                Text("Workout in progress — tap to return")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Image(systemName: "chevron.up")
                    .font(.caption)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.ssSurface)
            .overlay(
                RoundedRectangle(cornerRadius: 0)
                    .frame(height: 1)
                    .foregroundStyle(Color.ssAccent),
                alignment: .bottom
            )
        }
        .foregroundStyle(Color.primary)
    }
}
