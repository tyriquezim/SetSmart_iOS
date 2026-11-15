import SwiftUI

struct ForgotPasswordView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var sent = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if sent {
                        VStack(spacing: 20) {
                            Image(systemName: "envelope.fill")
                                .font(.system(size: 56))
                                .foregroundStyle(Color.ssAccent)
                            Text("Reset link sent")
                                .font(.title2.bold())
                                .foregroundStyle(Color.ssTextPrimary)
                            Text("Check your email and follow the link to reset your password.")
                                .multilineTextAlignment(.center)
                                .foregroundStyle(Color.ssTextSecondary)
                            Button("Done") { dismiss() }
                                .buttonStyle(PrimaryButtonStyle())
                        }
                        .padding(.top, 60)
                    } else {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Enter your email and we'll send you a reset link.")
                                .foregroundStyle(Color.ssTextSecondary)

                            SSTextField(placeholder: "Email", text: $email)
                                .keyboardType(.emailAddress)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)

                            if let errorMessage {
                                Text(errorMessage)
                                    .font(.caption)
                                    .foregroundStyle(Color.ssDanger)
                            }

                            Button(action: resetPassword) {
                                HStack(spacing: 8) {
                                    if isLoading { ProgressView().tint(.black) }
                                    Text("Send reset link")
                                }
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .disabled(isLoading || email.isEmpty)
                        }
                        .padding(.top, 24)
                    }
                }
                .padding(.horizontal, 24)
            }
            .background(Color.ssBackground.ignoresSafeArea())
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Forgot password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.ssAccent)
                }
            }
        }
    }

    private func resetPassword() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                try await appState.resetPassword(email: email)
                sent = true
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}
