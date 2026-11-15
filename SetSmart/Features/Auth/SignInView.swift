import SwiftUI

struct SignInView: View {
    @Environment(AppState.self) private var appState
    @Binding var showSignUp: Bool
    @Binding var showForgotPassword: Bool

    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 6) {
                    Text("SetSmart")
                        .font(.system(size: 40, weight: .black))
                        .foregroundStyle(Color.ssAccent)
                    Text("Your gym, tracked.")
                        .font(.subheadline)
                        .foregroundStyle(Color.ssTextSecondary)
                }
                .padding(.top, 60)

                // Fields
                VStack(spacing: 14) {
                    SSTextField(placeholder: "Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    SSTextField(placeholder: "Password", text: $password, isSecure: true)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(Color.ssDanger)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button(action: signIn) {
                        HStack(spacing: 8) {
                            if isLoading { ProgressView().tint(.black) }
                            Text("Sign in")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(isLoading || email.isEmpty || password.isEmpty)
                }

                // Links
                VStack(spacing: 14) {
                    Button("Forgot password?") { showForgotPassword = true }
                        .font(.subheadline)
                        .foregroundStyle(Color.ssAccent)

                    HStack(spacing: 4) {
                        Text("Don't have an account?")
                            .foregroundStyle(Color.ssTextSecondary)
                        Button("Sign up") { showSignUp = true }
                            .foregroundStyle(Color.ssAccent)
                    }
                    .font(.subheadline)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.ssBackground.ignoresSafeArea())
    }

    private func signIn() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                try await appState.signIn(email: email, password: password)
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}
