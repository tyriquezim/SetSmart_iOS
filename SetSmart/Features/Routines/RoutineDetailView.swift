import SwiftUI

struct RoutineDetailView: View {
    let routineId: UUID
    var onUpdate: (() -> Void)? = nil

    @State private var routine: Routine? = nil
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    @State private var showEditor = false

    @Environment(AppState.self) private var appState
    private let repo = RoutineRepository()

    var body: some View {
        Group {
            if let routine {
                detail(routine)
            } else if isLoading {
                ProgressView().tint(Color.ssAccent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let err = errorMessage {
                VStack(spacing: 12) {
                    Text(err).foregroundStyle(Color.ssDanger).multilineTextAlignment(.center)
                    Button("Retry") { Task { await load() } }.foregroundStyle(Color.ssAccent)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color.ssBackground.ignoresSafeArea())
        .navigationTitle(routine?.name ?? "Routine")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { showEditor = true }
                    .foregroundStyle(Color.ssAccent)
                    .disabled(routine == nil)
            }
        }
        .sheet(isPresented: $showEditor, onDismiss: { onUpdate?(); Task { await load() } }) {
            if let r = routine {
                NavigationStack { RoutineEditorView(existingRoutine: r) }
            }
        }
        .task { await load() }
    }

    @ViewBuilder
    private func detail(_ routine: Routine) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                // Start button
                VStack(spacing: 8) {
                    let hasAnySets   = routine.routineExercises.contains { !$0.sets.isEmpty }
                    let hasAnyCardio = routine.routineExercises.contains { $0.isCardio }
                    let canStart     = hasAnySets || hasAnyCardio
                    Button {
                        appState.startWorkout(from: routine)
                    } label: {
                        Label("Start workout", systemImage: "play.fill")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!canStart)

                    if !canStart {
                        Text("Add at least one exercise or cardio activity to this routine first.")
                            .font(.caption)
                            .foregroundStyle(Color.ssTextMuted)
                            .multilineTextAlignment(.center)
                    }
                }

                // Exercise cards
                VStack(spacing: 8) {
                    ForEach(routine.routineExercises) { re in
                        CardView {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(re.exercise?.name ?? "Unknown")
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(Color.ssTextPrimary)
                                    if re.isCardio {
                                        Text(cardioSubtitle(re))
                                            .font(.caption)
                                            .foregroundStyle(Color.ssTextSecondary)
                                    } else {
                                        Text("\(re.sets.count) set\(re.sets.count == 1 ? "" : "s") · \(formatRestSeconds(re.restSeconds))")
                                            .font(.caption)
                                            .foregroundStyle(Color.ssTextSecondary)
                                    }
                                    if let notes = re.notes, !notes.isEmpty {
                                        Text(notes)
                                            .font(.caption)
                                            .foregroundStyle(Color.ssTextMuted)
                                    }
                                }
                                Spacer()
                            }
                            .padding(16)
                        }
                    }
                }

                // Routine notes
                if let notes = routine.notes, !notes.isEmpty {
                    CardView {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Notes").font(.caption).foregroundStyle(Color.ssTextMuted)
                            Text(notes).foregroundStyle(Color.ssTextSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                    }
                }
            }
            .padding(16)
        }
    }

    private func cardioSubtitle(_ re: RoutineExercise) -> String {
        guard let s = re.targetDurationS, s > 0 else { return "Cardio · No goal" }
        let min = s / 60
        if min >= 60 {
            let h = min / 60; let m = min % 60
            return "Cardio · Goal \(m == 0 ? "\(h) h" : "\(h) h \(m) min")"
        }
        return "Cardio · Goal \(min) min"
    }

    @MainActor
    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            routine = try await repo.loadRoutine(id: routineId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
