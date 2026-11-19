import SwiftUI
import Supabase

struct PasswordResetView: View {
    @Environment(AppState.self) private var appState

    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var errorMessage: String? = nil
    @State private var isLoading = false
    @State private var isCancelling = false

    private var email: String { appState.session?.user.email ?? "" }
    private var canSave: Bool { !newPassword.isEmpty && !confirmPassword.isEmpty && !isLoading && !isCancelling }

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header — matches SignInView branding style
                VStack(spacing: 6) {
                    Text("SetSmart")
                        .font(.system(size: 40, weight: .black))
                        .foregroundStyle(Color.ssAccent)
                    Text("Set a new password")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.ssTextPrimary)
                    if !email.isEmpty {
                        Text("For \(email)")
                            .font(.subheadline)
                            .foregroundStyle(Color.ssTextSecondary)
                    }
                }
                .padding(.top, 60)

                // Fields
                VStack(spacing: 14) {
                    SSTextField(placeholder: "New password", text: $newPassword, isSecure: true)
                        .textContentType(.newPassword)

                    SSTextField(placeholder: "Confirm new password", text: $confirmPassword, isSecure: true)
                        .textContentType(.newPassword)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(Color.ssDanger)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button(action: savePassword) {
                        HStack(spacing: 8) {
                            if isLoading { ProgressView().tint(.black) }
                            Text("Save password")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!canSave)
                }

                Button(action: cancelRecovery) {
                    HStack(spacing: 6) {
                        if isCancelling {
                            ProgressView()
                                .tint(Color.ssDanger)
                                .scaleEffect(0.75)
                        }
                        Text("Cancel and sign out")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(Color.ssDanger)
                .disabled(isCancelling || isLoading)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .background(Color.ssBackground.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
        .interactiveDismissDisabled(true)
    }

    private func savePassword() {
        guard newPassword.count >= 8 else {
            errorMessage = "Password must be at least 8 characters."
            return
        }
        guard newPassword == confirmPassword else {
            errorMessage = "The passwords don't match."
            return
        }
        isLoading = true
        errorMessage = nil
        Task {
            do {
                try await appState.updatePassword(newPassword)
                // isRecoveringPassword is cleared by updatePassword; fullScreenCover dismisses automatically
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func cancelRecovery() {
        isCancelling = true
        Task {
            try? await appState.cancelPasswordRecovery()
            // .signedOut event clears isRecoveringPassword and returns to AuthView
            isCancelling = false
        }
    }
}
