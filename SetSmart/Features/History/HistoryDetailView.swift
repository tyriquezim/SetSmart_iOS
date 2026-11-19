import SwiftUI

struct HistoryDetailView: View {
    let session: WorkoutSessionSummary

    @Environment(AppState.self) private var appState

    @State private var detail: WorkoutSession?
    @State private var allBodyWeights: [BodyWeight] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let repo   = WorkoutRepository()
    private let bwRepo = BodyWeightRepository()

    var body: some View {
        Group {
            if let detail {
                content(detail)
            } else if let err = errorMessage {
                VStack(spacing: 12) {
                    Text(err)
                        .foregroundStyle(Color.ssDanger)
                        .multilineTextAlignment(.center)
                    Button("Retry") { Task { await load() } }
                        .foregroundStyle(Color.ssAccent)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ProgressView().tint(Color.ssAccent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color.ssBackground.ignoresSafeArea())
        .navigationTitle(session.name)
        .navigationBarTitleDisplayMode(.large)
        .task {
            await load()
            if let weights = try? await bwRepo.listBodyWeights() {
                allBodyWeights = weights
            }
        }
    }

    @ViewBuilder
    private func content(_ s: WorkoutSession) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header stats
                let duration = Int((s.finishedAt ?? s.startedAt).timeIntervalSince(s.startedAt))
                HStack(spacing: 12) {
                    statBadge(value: formatDuration(duration), label: "Duration")
                    if s.workoutSets.count > 0 {
                        statBadge(value: "\(s.workoutSets.count)", label: "Sets")
                    }
                    if !s.workoutCardio.isEmpty {
                        statBadge(value: "\(s.workoutCardio.count)", label: "Cardio")
                    }
                }
                energyCaptionView

                if let notes = s.notes, !notes.isEmpty {
                    CardView {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Notes").font(.caption).foregroundStyle(Color.ssTextMuted)
                            Text(notes).font(.subheadline).foregroundStyle(Color.ssTextSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                    }
                }

                // Cardio cards
                ForEach(s.workoutCardio.indices, id: \.self) { i in
                    cardioCard(s.workoutCardio[i])
                }

                // Sets grouped by exercise
                let grouped = groupedSets(s.workoutSets)
                ForEach(grouped, id: \.0) { exerciseName, sets in
                    CardView {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(exerciseName)
                                .font(.subheadline.weight(.semibold))
                            Divider().background(Color.ssBorder)
                            ForEach(sets.indices, id: \.self) { i in
                                let set = sets[i]
                                HStack {
                                    Text("Set \(i + 1)")
                                        .foregroundStyle(Color.ssTextSecondary)
                                    Spacer()
                                    Text("\(set.reps) reps")
                                    if let w = set.weightKg?.value, w > 0 {
                                        Text("· \(String(format: "%g", w)) kg")
                                            .foregroundStyle(Color.ssTextSecondary)
                                    }
                                }
                                .font(.subheadline)
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .padding(16)
        }
    }

    // MARK: - Energy

    private var sessionEnergy: WorkoutEnergyFull? {
        guard let profile = appState.profile, !allBodyWeights.isEmpty else { return nil }
        return estimateWorkoutEnergy(slot: session.asSlot, weights: allBodyWeights, profile: profile)
    }

    @ViewBuilder
    private var energyCaptionView: some View {
        if let wf = sessionEnergy {
            HStack(spacing: 6) {
                Text("Estimated energy burned:")
                    .font(.caption)
                    .foregroundStyle(Color.ssTextMuted)
                Text("\(formatEnergyEstimate(wf.totalKcal, unit: appState.energyUnit)) above resting")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.ssTextSecondary)
                InfoButton(content: .singleWorkout(wf), unit: appState.energyUnit)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else if appState.profile != nil {
            Text("Add your body details in Settings to see energy estimates.")
                .font(.caption)
                .foregroundStyle(Color.ssTextMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Cardio card

    private func cardioCard(_ row: WorkoutCardioRow) -> some View {
        CardView {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(row.exercise?.name ?? row.activity.label)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    if row.goalReached {
                        Label("Goal reached", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(Color.ssChartSeries)
                    } else if let goal = row.goalText {
                        Text(goal)
                            .font(.caption)
                            .foregroundStyle(Color.ssTextMuted)
                    }
                }
                HStack(spacing: 8) {
                    Label(row.durationText, systemImage: "clock")
                    if let dist = row.distanceM, dist > 0 {
                        Text("·")
                        Text(formatDistanceDisplay(metres: dist, activity: row.activity, weightUnit: appState.weightUnit))
                        if let pace = formatPace(distanceM: dist, durationS: row.durationS,
                                                 activity: row.activity, weightUnit: appState.weightUnit) {
                            Text("·")
                            Text(pace)
                        }
                    }
                }
                .font(.caption)
                .foregroundStyle(Color.ssTextMuted)

                if let profile = appState.profile, !allBodyWeights.isEmpty {
                    let est = row.energyEstimate(weights: allBodyWeights, profile: profile)
                    if case .result(let r) = est {
                        HStack(spacing: 4) {
                            Text(formatEnergyEstimate(r.kcal, unit: appState.energyUnit))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.ssTextSecondary)
                            if let resting = cardioResting() {
                                InfoButton(content: .singleCardio(r, restingResult: resting),
                                           unit: appState.energyUnit, weightUnit: appState.weightUnit)
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    private func cardioResting() -> RestingEnergyResult? {
        guard let profile = appState.profile else { return nil }
        let dayStr = localDayString(from: session.startedAt)
        guard let stats = bodyStatsOn(day: dayStr, weights: allBodyWeights, profile: profile) else { return nil }
        return restingEnergy(stats: stats)
    }

    // MARK: - Helpers

    private func statBadge(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.title3.weight(.bold))
            Text(label).font(.caption).foregroundStyle(Color.ssTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.ssSurface)
        .cornerRadius(12)
    }

    private func groupedSets(_ sets: [SessionSet]) -> [(String, [SessionSet])] {
        var order: [String] = []
        var dict:  [String: [SessionSet]] = [:]
        for s in sets {
            let name = s.exercise?.name ?? "Unknown"
            if dict[name] == nil { order.append(name) }
            dict[name, default: []].append(s)
        }
        return order.map { ($0, dict[$0]!) }
    }

    private func formatDuration(_ s: Int) -> String {
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, sec)
            : String(format: "%d:%02d", m, sec)
    }

    private func load() async {
        isLoading = true; errorMessage = nil
        do { detail = try await repo.fetchSession(id: session.id) }
        catch { errorMessage = error.localizedDescription }
        isLoading = false
    }
}
