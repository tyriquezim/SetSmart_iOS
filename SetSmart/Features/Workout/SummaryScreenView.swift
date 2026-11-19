import SwiftUI

struct SummaryScreenView: View {
    let workout: WorkoutState

    @Environment(AppState.self) private var appState

    @State private var notes    = ""
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var showDiscard = false

    private var totals: WorkoutTotals { workout.totals }
    private var prs: [UUID: PRResult] { workout.prs }
    private var unit: WeightUnit { appState.weightUnit }

    private var durationSeconds: Int {
        Int((workout.finishedAt ?? Date()).timeIntervalSince(workout.startedAt))
    }

    private var loggedCardioExercises: [WorkoutExercise] {
        workout.exercises.filter { $0.isCardio && $0.cardioLog != nil }
    }

    private var canSave: Bool {
        (totals.setsLogged > 0 || totals.cardioLogged > 0) && !isSaving
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    statsCards
                    if !loggedCardioExercises.isEmpty { cardioSection }
                    prSection
                    notesField
                    if let err = saveError {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(Color.ssDanger)
                    }
                    actionButtons
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .background(Color.ssBackground)
            .navigationTitle("Workout Complete")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Discard") { showDiscard = true }
                        .foregroundStyle(Color.ssDanger)
                }
            }
        }
        .confirmationDialog("Discard workout?", isPresented: $showDiscard, titleVisibility: .visible) {
            Button("Discard", role: .destructive) { appState.discardWorkout() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your sets won't be saved.")
        }
    }

    // MARK: - Stats cards

    private var statsCards: some View {
        HStack(spacing: 12) {
            statCard(value: formatDuration(durationSeconds), label: "Duration")
            if totals.setsLogged > 0 {
                statCard(value: "\(totals.setsLogged)", label: "Sets")
                statCard(
                    value: "\(String(format: "%g", unit.fromKg(totals.volumeKg))) \(unit.rawValue)",
                    label: "Volume"
                )
            }
            if totals.cardioSeconds > 0 {
                statCard(value: formatCardioTime(totals.cardioSeconds), label: "Cardio")
            }
        }
    }

    private func statCard(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.title3.weight(.bold))
            Text(label).font(.caption).foregroundStyle(Color.ssTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.ssSurface)
        .cornerRadius(12)
    }

    // MARK: - Cardio section

    private var cardioSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cardio")
                .font(.headline)

            ForEach(loggedCardioExercises, id: \.exerciseId) { ex in
                if let log = ex.cardioLog {
                    HStack {
                        Image(systemName: ex.cardio?.activity.systemImage ?? "figure.run")
                            .foregroundStyle(Color.ssAccent)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(ex.name).font(.subheadline.weight(.semibold))
                            Text(cardioSummaryText(
                                durationS:  log.durationS,
                                distanceM:  log.distanceM,
                                activity:   ex.cardio?.activity ?? .other,
                                weightUnit: unit
                            ))
                            .font(.caption)
                            .foregroundStyle(Color.ssTextSecondary)
                        }
                        Spacer()
                        if let goalS = ex.cardio?.targetDurationS, goalS > 0 {
                            if log.durationS >= goalS {
                                Image(systemName: "flag.fill")
                                    .foregroundStyle(Color.ssAccent)
                                    .font(.caption)
                            }
                        }
                    }
                    .padding(12)
                    .background(Color.ssSurface)
                    .cornerRadius(10)
                }
            }
        }
    }

    // MARK: - PR section

    @ViewBuilder
    private var prSection: some View {
        let prList: [(String, WorkoutExercise)] = workout.exercises.compactMap { ex in
            guard prs[ex.exerciseId] != nil else { return nil }
            return (ex.name, ex)
        }
        if !prList.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Personal Records 🏆")
                    .font(.headline)
                ForEach(prList, id: \.0) { name, ex in
                    let bestE1rm = ex.logged.compactMap { s -> Double? in
                        guard let w = s.weightKg else { return nil }
                        return WorkoutState.epley(weight: w, reps: s.reps)
                    }.max()

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(name).font(.subheadline.weight(.semibold))
                            if let e = bestE1rm {
                                Text("1RM: \(String(format: "%.1f", unit.fromKg(e))) \(unit.rawValue)")
                                    .font(.caption)
                                    .foregroundStyle(Color.ssTextSecondary)
                            }
                        }
                        Spacer()
                        Image(systemName: "trophy.fill")
                            .foregroundStyle(Color.ssAccent)
                    }
                    .padding(12)
                    .background(Color.ssSurface)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.ssAccent.opacity(0.4), lineWidth: 1))
                }
            }
        }
    }

    // MARK: - Notes

    private var notesField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.ssTextSecondary)
            TextField("How did it go?", text: $notes, axis: .vertical)
                .lineLimit(3...6)
                .padding(12)
                .background(Color.ssSurface)
                .cornerRadius(12)
        }
    }

    // MARK: - Actions

    private var actionButtons: some View {
        Button {
            isSaving = true; saveError = nil
            Task {
                do { try await appState.finishAndSaveWorkout(notes: notes) }
                catch { saveError = error.localizedDescription }
                isSaving = false
            }
        } label: {
            if isSaving {
                ProgressView().tint(.black).frame(maxWidth: .infinity).frame(height: 48)
            } else {
                Text("Save Workout").frame(maxWidth: .infinity).frame(height: 48)
            }
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(!canSave)
    }

    private func formatDuration(_ s: Int) -> String {
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, sec)
            : String(format: "%d:%02d", m, sec)
    }
}
