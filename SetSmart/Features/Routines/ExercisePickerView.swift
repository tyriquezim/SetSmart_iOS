import SwiftUI

private enum ExerciseTab: String, CaseIterable {
    case weights = "Weights"
    case cardio  = "Cardio"
}

struct ExercisePickerView: View {
    let onSelect: (Exercise) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var exercises: [Exercise] = []
    @State private var searchText = ""
    @State private var muscleFilter: MuscleGroup? = nil
    @State private var tab: ExerciseTab = .weights
    @State private var showCreate = false

    private let repo = ExerciseRepository()

    private var filteredWeights: [Exercise] {
        exercises.filter {
            $0.isWeights &&
            (muscleFilter == nil || $0.muscleGroup == muscleFilter) &&
            (searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText))
        }
    }

    private var filteredCardio: [Exercise] {
        exercises.filter {
            $0.isCardio &&
            (searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText))
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                ForEach(ExerciseTab.allCases, id: \.self) { t in
                    Text(t.rawValue).tag(t)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.ssBackground)

            List {
                switch tab {
                case .weights: weightsList
                case .cardio:  cardioList
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.ssBackground.ignoresSafeArea())
        }
        .searchable(text: $searchText,
                    prompt: tab == .weights ? "Search exercises" : "Search cardio")
        .navigationTitle("Pick an exercise")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }.foregroundStyle(Color.ssAccent)
            }
            if tab == .weights {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("All muscles") { muscleFilter = nil }
                        ForEach(MuscleGroup.weightsGroups) { group in
                            Button(group.rawValue) { muscleFilter = group }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .foregroundStyle(muscleFilter != nil ? Color.ssAccent : Color.ssTextSecondary)
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { showCreate = true } label: {
                    Image(systemName: "plus").foregroundStyle(Color.ssAccent)
                }
            }
        }
        .sheet(isPresented: $showCreate, onDismiss: { Task { await load() } }) {
            NavigationStack { ExerciseFormView() }
        }
        .onChange(of: tab) { _, _ in muscleFilter = nil }
        .task { await load() }
    }

    @ViewBuilder
    private var weightsList: some View {
        ForEach(filteredWeights) { exercise in
            exerciseRow(exercise)
        }
        if filteredWeights.isEmpty {
            Text("No exercises found")
                .foregroundStyle(Color.ssTextMuted)
                .listRowBackground(Color.ssBackground)
        }
    }

    @ViewBuilder
    private var cardioList: some View {
        ForEach(filteredCardio) { exercise in
            exerciseRow(exercise)
        }
        if filteredCardio.isEmpty {
            Text("No cardio exercises found")
                .foregroundStyle(Color.ssTextMuted)
                .listRowBackground(Color.ssBackground)
        }
    }

    private func exerciseRow(_ exercise: Exercise) -> some View {
        Button {
            onSelect(exercise)
            dismiss()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.name).foregroundStyle(Color.ssTextPrimary)
                    Text(subtitle(for: exercise))
                        .font(.caption).foregroundStyle(Color.ssTextMuted)
                }
                Spacer()
                Image(systemName: "plus.circle").foregroundStyle(Color.ssAccent)
            }
            .padding(.vertical, 4)
        }
        .listRowBackground(Color.ssSurface)
    }

    private func subtitle(for exercise: Exercise) -> String {
        guard exercise.isCardio else {
            return "\(exercise.muscleGroup.rawValue) · \(exercise.equipment.rawValue)"
        }
        if exercise.isBuiltIn {
            return exercise.equipment.rawValue
        }
        let activity = exercise.cardioActivity?.label.lowercased() ?? "other"
        return "Counts as \(activity)"
    }

    @MainActor
    private func load() async {
        exercises = (try? await repo.listExercises()) ?? []
    }
}
