import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if appState.isLoadingAuth {
                ZStack {
                    Color.ssBackground.ignoresSafeArea()
                    ProgressView()
                        .tint(Color.ssAccent)
                }
            } else if appState.isAuthenticated {
                MainTabView()
            } else {
                AuthView()
            }
        }
        .preferredColorScheme(.dark)
    }
}
