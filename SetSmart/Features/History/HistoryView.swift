import SwiftUI

struct HistoryView: View {
    @Environment(AppState.self) private var appState

    @State private var sessions: [WorkoutSessionSummary] = []
    @State private var allBodyWeights: [BodyWeight] = []
    @State private var isLoading = false
    @State private var canLoadMore = true
    @State private var errorMessage: String?

    private let repo   = WorkoutRepository()
    private let bwRepo = BodyWeightRepository()

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty && isLoading {
                    ProgressView().tint(Color.ssAccent)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if sessions.isEmpty && !isLoading {
                    emptyState
                } else {
                    list
                }
            }
            .background(Color.ssBackground.ignoresSafeArea())
            .navigationTitle("History")
        }
        .task {
            await loadNext()
            if let weights = try? await bwRepo.listBodyWeights() {
                allBodyWeights = weights
            }
        }
    }

    private var list: some View {
        List {
            ForEach(sessions) { session in
                NavigationLink(destination: HistoryDetailView(session: session)) {
                    sessionRow(session)
                }
                .listRowBackground(Color.ssSurface)
                .listRowSeparatorTint(Color.ssBorder)
            }

            if canLoadMore {
                Button("Load more") { Task { await loadNext() } }
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
            Text("No workouts yet")
                .font(.headline)
                .foregroundStyle(Color.ssTextMuted)
            Text("Complete your first workout to see it here.")
                .font(.subheadline)
                .foregroundStyle(Color.ssTextMuted)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func sessionRow(_ s: WorkoutSessionSummary) -> some View {
        let energy = sessionWorkoutEnergy(s)
        return VStack(alignment: .leading, spacing: 4) {
            Text(s.name)
                .font(.body.weight(.semibold))
            Text(s.startedAt, style: .date)
                .font(.subheadline)
                .foregroundStyle(Color.ssTextSecondary)
            HStack(spacing: 8) {
                Label("\(s.setCount) sets", systemImage: "dumbbell.fill")
                if s.volumeKg > 0 {
                    Label(String(format: "%g kg", s.volumeKg), systemImage: "scalemass.fill")
                }
                if let (wr, rr) = energy {
                    Text("·")
                    Text(formatEnergyEstimate(wr.kcal, unit: appState.energyUnit))
                    InfoButton(content: .singleWorkout(wr, restingResult: rr), unit: appState.energyUnit)
                }
            }
            .font(.caption)
            .foregroundStyle(Color.ssTextMuted)
        }
        .padding(.vertical, 4)
    }

    private func sessionWorkoutEnergy(_ s: WorkoutSessionSummary) -> (WorkoutEnergyResult, RestingEnergyResult)? {
        guard let profile   = appState.profile,
              let finishedAt = s.finishedAt,
              !allBodyWeights.isEmpty
        else { return nil }
        let dayStr = localDayString(from: s.startedAt)
        guard let stats   = bodyStatsOn(day: dayStr, weights: allBodyWeights, profile: profile),
              let resting = restingEnergy(stats: stats)
        else { return nil }
        let wr = workoutEnergyFor(startedAt: s.startedAt, finishedAt: finishedAt, stats: stats)
        return (wr, resting)
    }

    private func reload() async {
        sessions = []
        canLoadMore = true
        await loadNext()
    }

    private func loadNext() async {
        guard !isLoading, canLoadMore else { return }
        isLoading = true
        errorMessage = nil
        do {
            let before = sessions.last?.startedAt
            let batch  = try await repo.fetchHistory(limit: 20, before: before)
            sessions.append(contentsOf: batch)
            canLoadMore = batch.count == 20
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
