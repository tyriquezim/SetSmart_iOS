import SwiftUI

struct HistoryView: View {
    @Environment(AppState.self) private var appState

    @State private var workouts: [WorkoutSessionSummary] = []
    @State private var allBodyWeights: [BodyWeight] = []
    @State private var workoutLimit = 20
    @State private var lastWorkoutCount = 0
    @State private var isLoading = false

    private let workoutRepo = WorkoutRepository()
    private let bwRepo      = BodyWeightRepository()

    var body: some View {
        NavigationStack {
            Group {
                if workouts.isEmpty && isLoading {
                    ProgressView().tint(Color.ssAccent)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if workouts.isEmpty && !isLoading {
                    emptyState
                } else {
                    list
                }
            }
            .background(Color.ssBackground.ignoresSafeArea())
            .navigationTitle("History")
            .navigationDestination(for: WorkoutSessionSummary.self) { session in
                HistoryDetailView(session: session)
            }
        }
        .task {
            isLoading = true
            async let w  = workoutRepo.fetchHistory(limit: workoutLimit)
            async let bw = bwRepo.listBodyWeights()
            workouts       = (try? await w)  ?? []
            allBodyWeights = (try? await bw) ?? []
            lastWorkoutCount = workouts.count
            isLoading        = false
        }
    }

    private var list: some View {
        List {
            ForEach(workouts) { session in
                NavigationLink(value: session) {
                    workoutRow(session)
                }
                .listRowBackground(Color.ssSurface)
                .listRowSeparatorTint(Color.ssBorder)
            }

            if lastWorkoutCount == workoutLimit {
                Button("Load more") { Task { await loadMore() } }
                    .foregroundStyle(Color.ssAccent)
                    .listRowBackground(Color.ssBackground)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .refreshable { await reload() }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.ssTextMuted)
            Text("Nothing logged yet")
                .font(.headline)
                .foregroundStyle(Color.ssTextMuted)
            Text("Finish a workout and it'll show up here.")
                .font(.subheadline)
                .foregroundStyle(Color.ssTextMuted)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Workout row

    private func workoutRow(_ s: WorkoutSessionSummary) -> some View {
        let energy = sessionEnergy(s)
        return VStack(alignment: .leading, spacing: 4) {
            Text(s.name)
                .font(.body.weight(.semibold))
            Text(s.startedAt, style: .date)
                .font(.subheadline)
                .foregroundStyle(Color.ssTextSecondary)
            HStack(spacing: 8) {
                if s.setCount > 0 {
                    Label("\(s.setCount) sets", systemImage: "dumbbell.fill")
                    if s.volumeKg > 0 {
                        Label(String(format: "%g kg", s.volumeKg), systemImage: "scalemass.fill")
                    }
                }
                if !s.workoutCardio.isEmpty {
                    let totalCardioS = s.workoutCardio.reduce(0) { $0 + $1.durationS }
                    Label("\(s.workoutCardio.count) cardio · \(formatCardioTime(totalCardioS))",
                          systemImage: "figure.run")
                }
                if let wf = energy {
                    Text("·")
                    Text(formatEnergyEstimate(wf.totalKcal, unit: appState.energyUnit))
                    InfoButton(content: .singleWorkout(wf), unit: appState.energyUnit)
                }
            }
            .font(.caption)
            .foregroundStyle(Color.ssTextMuted)
        }
        .padding(.vertical, 4)
    }

    private func sessionEnergy(_ s: WorkoutSessionSummary) -> WorkoutEnergyFull? {
        guard let profile = appState.profile, !allBodyWeights.isEmpty else { return nil }
        return estimateWorkoutEnergy(slot: s.asSlot, weights: allBodyWeights, profile: profile)
    }

    // MARK: - Loading

    private func reload() async {
        workoutLimit = 20
        isLoading    = true
        async let w  = workoutRepo.fetchHistory(limit: workoutLimit)
        async let bw = bwRepo.listBodyWeights()
        workouts       = (try? await w)  ?? []
        allBodyWeights = (try? await bw) ?? []
        lastWorkoutCount = workouts.count
        isLoading        = false
    }

    private func loadMore() async {
        workoutLimit += 20
        async let w  = workoutRepo.fetchHistory(limit: workoutLimit)
        workouts         = (try? await w) ?? workouts
        lastWorkoutCount = workouts.count
    }
}
