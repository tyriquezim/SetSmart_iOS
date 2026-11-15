import SwiftUI

struct SignUpView: View {
    @Environment(AppState.self) private var appState
    @Binding var showSignUp: Bool

    @State private var displayName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var awaitingConfirmation = false

    private var canSubmit: Bool {
        !isLoading &&
        !displayName.isEmpty &&
        !email.isEmpty &&
        password.count >= 8 &&
        password == confirmPassword
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 6) {
                    Text("Create account")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(Color.ssTextPrimary)
                    Text("Join SetSmart")
                        .font(.subheadline)
                        .foregroundStyle(Color.ssTextSecondary)
                }
                .padding(.top, 60)

                if awaitingConfirmation {
                    confirmationView
                } else {
                    formView
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.ssBackground.ignoresSafeArea())
    }

    private var formView: some View {
        VStack(spacing: 14) {
            SSTextField(placeholder: "Name", text: $displayName)
            SSTextField(placeholder: "Email", text: $email)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            SSTextField(placeholder: "Password (8+ characters)", text: $password, isSecure: true)
            SSTextField(placeholder: "Confirm password", text: $confirmPassword, isSecure: true)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(Color.ssDanger)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button(action: signUp) {
                HStack(spacing: 8) {
                    if isLoading { ProgressView().tint(.black) }
                    Text("Create account")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!canSubmit)

            Button("Already have an account? Sign in") { showSignUp = false }
                .font(.subheadline)
                .foregroundStyle(Color.ssAccent)
        }
    }

    private var confirmationView: some View {
        VStack(spacing: 20) {
            Image(systemName: "envelope.badge.checkmark.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.ssAccent)
            Text("Check your email")
                .font(.title2.bold())
                .foregroundStyle(Color.ssTextPrimary)
            Text("We sent a confirmation link to \(email). Confirm your account then sign in.")
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.ssTextSecondary)
            Button("Back to sign in") { showSignUp = false }
                .buttonStyle(PrimaryButtonStyle())
        }
    }

    private func signUp() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                try await appState.signUp(email: email, password: password, displayName: displayName)
                awaitingConfirmation = true
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}
