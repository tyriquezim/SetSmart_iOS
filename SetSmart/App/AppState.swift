import Observation
import Foundation
import Supabase

@Observable
final class AppState {
    var session: Session?
    var profile: Profile?
    var isLoadingAuth = true

    var isAuthenticated: Bool { session != nil }
    var weightUnit: WeightUnit { profile?.weightUnit ?? .kg }
    var energyUnit: EnergyUnit { profile?.energyUnit ?? .kj }

    private let client = SupabaseClientProvider.shared
    private let profileRepo = ProfileRepository()

    init() {
        Task { await listenForAuthChanges() }
    }

    @MainActor
    private func listenForAuthChanges() async {
        for await (event, session) in await client.auth.authStateChanges {
            self.session = session
            switch event {
            case .initialSession, .signedIn:
                if session != nil { await loadProfile() }
            case .signedOut:
                profile = nil
            default:
                break
            }
            isLoadingAuth = false
        }
    }

    @MainActor
    func loadProfile() async {
        do {
            profile = try await profileRepo.fetchProfile()
        } catch {
            // Non-fatal — continue with defaults
        }
    }

    func signIn(email: String, password: String) async throws {
        try await client.auth.signIn(email: email, password: password)
    }

    func signUp(email: String, password: String, displayName: String) async throws {
        try await client.auth.signUp(
            email: email,
            password: password,
            data: ["display_name": .string(displayName)]
        )
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }

    func resetPassword(email: String) async throws {
        try await client.auth.resetPasswordForEmail(
            email,
            redirectTo: URL(string: "https://setsmart.netlify.app")
        )
    }

    @MainActor
    func updateProfile(displayName: String?, weightUnit: WeightUnit, energyUnit: EnergyUnit) async throws {
        guard var updated = profile else { return }
        updated.displayName = displayName
        updated.weightUnit = weightUnit
        updated.energyUnit = energyUnit
        try await profileRepo.updateProfile(updated)
        profile = updated
    }
}
