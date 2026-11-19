import Observation
import Foundation
import Supabase

// MARK: - Delete account errors

enum DeleteAccountError: LocalizedError {
    case wrongPassword
    case rpcFailed(String)

    var errorDescription: String? {
        switch self {
        case .wrongPassword:
            return "That password is incorrect."
        case .rpcFailed(let msg):
            return "Your account couldn't be deleted, and nothing was removed. Please try again. (\(msg))"
        }
    }
}

// MARK: - AppState

@Observable
final class AppState {
    var session: Session?
    var profile: Profile?
    var isLoadingAuth = true

    var isAuthenticated: Bool { session != nil }
    var weightUnit: WeightUnit { profile?.weightUnit ?? .kg }
    var energyUnit: EnergyUnit { profile?.energyUnit ?? .kj }

    // MARK: - Tab selection (0=Home,1=Routines,2=Food,3=Progress,4=History)
    var selectedTab: Int = 0

    // MARK: - Workout Player
    var activeWorkout: WorkoutState?
    var isWorkoutPlayerVisible = false

    // MARK: - One-time notices (in memory only, not persisted)
    var deletionNotice: String? = nil

    private let client = SupabaseClientProvider.shared
    private let profileRepo = ProfileRepository()
    private let workoutRepo = WorkoutRepository()
    private let persistence = WorkoutPersistence()
    private let outbox      = WorkoutOutbox()

    init() {
        NotificationService.shared.requestPermission()
        Task { await listenForAuthChanges() }
    }

    // MARK: - Auth

    @MainActor
    private func listenForAuthChanges() async {
        for await (event, session) in await client.auth.authStateChanges {
            self.session = session
            switch event {
            case .initialSession, .signedIn:
                if let session {
                    await loadProfile()
                    await restoreWorkout(userId: session.user.id)
                    Task { await outbox.drain(for: session.user.id, using: workoutRepo) }
                }
            case .signedOut:
                profile = nil
                activeWorkout = nil
                isWorkoutPlayerVisible = false
                persistence.delete()
            default:
                break
            }
            isLoadingAuth = false
        }
    }

    @MainActor
    func loadProfile() async {
        do { profile = try await profileRepo.fetchProfile() } catch {}
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
        updated.weightUnit  = weightUnit
        updated.energyUnit  = energyUnit
        try await profileRepo.updateProfile(updated)
        profile = updated
    }

    @MainActor
    func updateBodyDetails(
        heightCm:      Double?,
        birthYear:     Int?,
        sex:           Sex?,
        dailyActivity: DailyActivity?,
        workoutEffort: WorkoutEffort
    ) async throws {
        guard var updated = profile else { return }
        updated.heightCm      = heightCm
        updated.birthYear     = birthYear
        updated.sex           = sex
        updated.dailyActivity = dailyActivity
        updated.workoutEffort = workoutEffort
        try await profileRepo.updateProfile(updated)
        profile = updated
    }

    // MARK: - Delete account

    @MainActor
    func deleteAccount(password: String) async throws {
        guard let email = session?.user.email else { return }

        // 1. Re-verify the password
        do {
            try await client.auth.signIn(email: email, password: password)
        } catch {
            throw DeleteAccountError.wrongPassword
        }

        // 2. Call the RPC — deletes all user data in one transaction
        do {
            try await client.rpc("delete_my_account").execute()
        } catch {
            throw DeleteAccountError.rpcFailed(error.localizedDescription)
        }

        // 3. Cancel notifications and clear all local state
        let userId = session?.user.id
        NotificationService.shared.cancel()
        persistence.delete()
        if let uid = userId { outbox.deleteAll(for: uid) }
        WorkoutSettings.shared.reset()

        // 4. Sign out locally — the server session no longer exists
        try? await client.auth.signOut(scope: .local)

        // 5. Leave a one-time notice for the sign-in screen
        deletionNotice = "Your account and all its data have been deleted."
    }

    // MARK: - Workout management

    @MainActor
    func startWorkout(from routine: Routine) {
        NotificationService.shared.requestPermission()
        activeWorkout = WorkoutState.create(from: routine, now: .now)
        isWorkoutPlayerVisible = true
        if let userId = session?.user.id {
            persistence.save(activeWorkout!, userId: userId)
        }
        // Load exercise history in background — non-blocking, used for set prefill hints
        let exerciseIds = routine.routineExercises.map { $0.exerciseId }
        Task { await loadExerciseHistory(for: exerciseIds) }
    }

    @MainActor
    private func loadExerciseHistory(for exerciseIds: [UUID]) async {
        guard activeWorkout != nil else { return }
        do {
            let history = try await workoutRepo.loadExerciseHistory(exerciseIds: exerciseIds)
            for (idx, ex) in activeWorkout!.exercises.enumerated() {
                activeWorkout!.exercises[idx].history = history[ex.exerciseId]
            }
            if let userId = session?.user.id {
                persistence.save(activeWorkout!, userId: userId)
            }
        } catch { /* non-fatal */ }
    }

    @MainActor
    func applyWorkoutAction(_ action: WorkoutAction) {
        guard activeWorkout != nil else { return }
        activeWorkout!.apply(action, now: .now)
        if let userId = session?.user.id {
            persistence.save(activeWorkout!, userId: userId)
        }
        // Schedule / cancel notifications
        switch activeWorkout!.phase {
        case .rest(_, let endsAt):
            let nextSet: String? = {
                guard let idx = activeWorkout!.queue.first else { return nil }
                let ex = activeWorkout!.exercises[idx]
                let setNum = ex.logged.count + 1
                return "\(ex.name) · Set \(setNum) of \(ex.sets.count)"
            }()
            NotificationService.shared.scheduleRestEnd(at: endsAt, nextSet: nextSet)
            NotificationService.shared.cancelCardioGoal()
        case .cardio(let t) where t.isRunning:
            NotificationService.shared.cancel()
            if let runningSince = t.runningSince,
               let plan = activeWorkout!.exercises[t.exerciseIndex].cardio,
               let goalS = plan.targetDurationS, goalS > 0 {
                let remainingMs = Double(goalS) * 1000 - t.accumulatedMs
                if remainingMs > 0 {
                    let fireDate = runningSince.addingTimeInterval(remainingMs / 1000)
                    let goalMin  = max(1, goalS / 60)
                    let name     = activeWorkout!.exercises[t.exerciseIndex].name
                    NotificationService.shared.scheduleCardioGoal(at: fireDate,
                                                                  exerciseName: name,
                                                                  goalMin: goalMin)
                }
            }
        default:
            NotificationService.shared.cancel()
        }
    }

    @MainActor
    func discardWorkout() {
        activeWorkout = nil
        isWorkoutPlayerVisible = false
        NotificationService.shared.cancel()
        persistence.delete()
    }

    @MainActor
    func finishAndSaveWorkout(notes: String) async throws {
        guard let workout = activeWorkout else { return }
        do {
            try await workoutRepo.logWorkout(state: workout, notes: notes.isEmpty ? nil : notes)
        } catch {
            // Save to outbox so it can be retried on next launch
            if let userId = session?.user.id {
                outbox.add(state: workout, notes: notes.isEmpty ? nil : notes, userId: userId)
            }
            throw error
        }
        activeWorkout = nil
        isWorkoutPlayerVisible = false
        NotificationService.shared.cancel()
        persistence.delete()
    }

    @MainActor
    private func restoreWorkout(userId: UUID) async {
        guard var saved = persistence.load(for: userId) else { return }
        // If rest already ended >60 s ago, skip the alarm and move straight to set
        if case .rest(_, let endsAt) = saved.phase,
           Date().timeIntervalSince(endsAt) > 60 {
            saved.apply(.endRest, now: .now)
            NotificationService.shared.cancel()
        }
        activeWorkout = saved
        // Don't auto-show the player — show the resume banner instead
    }
}
