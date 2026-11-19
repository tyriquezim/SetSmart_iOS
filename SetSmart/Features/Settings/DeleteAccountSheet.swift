import SwiftUI

struct DeleteAccountSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var password    = ""
    @State private var isDeleting  = false
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // What gets deleted
                    VStack(alignment: .leading, spacing: 12) {
                        Text("This permanently deletes:")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.ssTextPrimary)

                        VStack(alignment: .leading, spacing: 8) {
                            bulletRow("your workouts (weights and cardio) and routines")
                            bulletRow("your custom exercises and foods")
                            bulletRow("your food log, targets and weigh-ins")
                            bulletRow("your profile, body details and login")
                        }
                    }

                    Text("**This can't be undone**, and the data can't be recovered. You can sign up again with the same email later, but you'll start from scratch.")
                        .font(.subheadline)
                        .foregroundStyle(Color.ssTextSecondary)

                    // Password confirmation
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Enter your password to confirm")
                            .font(.caption)
                            .foregroundStyle(Color.ssTextSecondary)
                        SecureField("Password", text: $password)
                            .textContentType(.password)
                            .padding(14)
                            .background(Color.ssSurface)
                            .cornerRadius(10)
                            .disabled(isDeleting)
                    }

                    if let err = errorMessage {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(Color.ssDanger)
                    }

                    // Delete button
                    Button { deleteAccount() } label: {
                        HStack(spacing: 8) {
                            if isDeleting { ProgressView().tint(.white) }
                            Text("Delete my account")
                        }
                    }
                    .buttonStyle(DangerButtonStyle())
                    .disabled(password.isEmpty || isDeleting)
                }
                .padding(20)
            }
            .background(Color.ssBackground.ignoresSafeArea())
            .navigationTitle("Delete your account?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.ssAccent)
                        .disabled(isDeleting)
                }
            }
        }
        .interactiveDismissDisabled(isDeleting)
        .preferredColorScheme(.dark)
    }

    private func bulletRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•").foregroundStyle(Color.ssDanger)
            Text(text).foregroundStyle(Color.ssTextSecondary)
        }
        .font(.subheadline)
    }

    private func deleteAccount() {
        isDeleting = true
        errorMessage = nil
        Task {
            do {
                try await appState.deleteAccount(password: password)
                // AppState navigates back to sign-in automatically — no dismiss needed here
            } catch {
                errorMessage = error.localizedDescription
                isDeleting = false
            }
        }
    }
}
