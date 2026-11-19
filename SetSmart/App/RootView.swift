import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState

    // Shown when the user taps "Send a new link" from the expired-link alert
    @State private var showForgotPasswordAfterExpiredLink = false

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
        // Handle setsmart://reset-password deep links
        .onOpenURL { url in
            Task {
                do {
                    try await appState.handlePasswordResetURL(url)
                } catch {
                    appState.resetLinkError = error.localizedDescription
                }
            }
        }
        // Alert when the reset link has already been used or has expired
        .alert(
            "Link expired",
            isPresented: Binding(
                get: { appState.resetLinkError != nil },
                set: { if !$0 { appState.resetLinkError = nil } }
            )
        ) {
            Button("Send a new link") {
                appState.resetLinkError = nil
                showForgotPasswordAfterExpiredLink = true
            }
            Button("OK", role: .cancel) {
                appState.resetLinkError = nil
            }
        } message: {
            Text("That reset link has expired or was already used.")
        }
        .sheet(isPresented: $showForgotPasswordAfterExpiredLink) {
            ForgotPasswordView()
        }
        // Full-screen password-reset UI — only Save or Cancel can close it
        .fullScreenCover(
            isPresented: Binding(get: { appState.isRecoveringPassword }, set: { _ in })
        ) {
            PasswordResetView()
        }
    }
}
