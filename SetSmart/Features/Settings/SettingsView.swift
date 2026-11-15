import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var displayName = ""
    @State private var weightUnit: WeightUnit = .kg
    @State private var energyUnit: EnergyUnit = .kj
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showSignOutConfirm = false
    @State private var showForgotPassword = false

    var body: some View {
        List {
            Section("Profile") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Display name")
                        .font(.caption)
                        .foregroundStyle(Color.ssTextSecondary)
                    SSTextField(placeholder: "Your name", text: $displayName)
                }
                .listRowBackground(Color.ssSurface)
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
            }

            Section("Units") {
                Picker("Weight", selection: $weightUnit) {
                    ForEach(WeightUnit.allCases, id: \.self) { unit in
                        Text(unit.label).tag(unit)
                    }
                }
                .foregroundStyle(Color.ssTextPrimary)
                .tint(Color.ssAccent)
                .listRowBackground(Color.ssSurface)

                Picker("Energy", selection: $energyUnit) {
                    ForEach(EnergyUnit.allCases, id: \.self) { unit in
                        Text(unit.label).tag(unit)
                    }
                }
                .foregroundStyle(Color.ssTextPrimary)
                .tint(Color.ssAccent)
                .listRowBackground(Color.ssSurface)
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(Color.ssDanger)
                        .listRowBackground(Color.ssSurface)
                }
            }

            Section {
                Button(action: saveProfile) {
                    HStack(spacing: 8) {
                        if isSaving { ProgressView().tint(.black) }
                        Text("Save changes")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isSaving)
                .listRowBackground(Color.ssBackground)
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
            }

            Section("Account") {
                Button("Change password") { showForgotPassword = true }
                    .foregroundStyle(Color.ssAccent)
                    .listRowBackground(Color.ssSurface)

                Button("Sign out") { showSignOutConfirm = true }
                    .foregroundStyle(Color.ssDanger)
                    .listRowBackground(Color.ssSurface)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.ssBackground.ignoresSafeArea())
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: loadFromProfile)
        .confirmationDialog("Sign out?", isPresented: $showSignOutConfirm, titleVisibility: .visible) {
            Button("Sign out", role: .destructive) { signOut() }
        } message: {
            Text("You'll need to sign back in to access your workouts.")
        }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView()
        }
    }

    private func loadFromProfile() {
        guard let profile = appState.profile else { return }
        displayName = profile.displayName ?? ""
        weightUnit  = profile.weightUnit
        energyUnit  = profile.energyUnit
    }

    private func saveProfile() {
        isSaving = true
        errorMessage = nil
        Task {
            do {
                try await appState.updateProfile(
                    displayName: displayName.isEmpty ? nil : displayName,
                    weightUnit: weightUnit,
                    energyUnit: energyUnit
                )
            } catch {
                errorMessage = error.localizedDescription
            }
            isSaving = false
        }
    }

    private func signOut() {
        Task { try? await appState.signOut() }
    }
}
