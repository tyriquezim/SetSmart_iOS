import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home",     systemImage: "house.fill") }

            RoutinesView()
                .tabItem { Label("Routines", systemImage: "list.bullet.rectangle.fill") }

            FoodView()
                .tabItem { Label("Food",     systemImage: "fork.knife") }

            ProgressTabView()
                .tabItem { Label("Progress", systemImage: "chart.xyaxis.line") }

            HistoryView()
                .tabItem { Label("History",  systemImage: "clock.fill") }
        }
        .tint(Color.ssAccent)
    }
}
