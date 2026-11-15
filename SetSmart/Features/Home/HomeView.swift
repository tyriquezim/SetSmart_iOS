import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    // Greeting
                    VStack(alignment: .leading, spacing: 4) {
                        Text(greeting)
                            .font(.title3)
                            .foregroundStyle(Color.ssTextSecondary)
                        Text(appState.profile?.firstName ?? "Athlete")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(Color.ssTextPrimary)
                    }

                    CardView {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Coming in Phase 2", systemImage: "dumbbell.fill")
                                .font(.headline)
                                .foregroundStyle(Color.ssAccent)
                            Text("Routines, workouts, body weight and food cards will appear here.")
                                .font(.subheadline)
                                .foregroundStyle(Color.ssTextSecondary)
                        }
                        .padding(16)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color.ssBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(Color.ssTextSecondary)
                    }
                }
            }
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good morning,"
        case 12..<17: return "Good afternoon,"
        default:      return "Good evening,"
        }
    }
}
