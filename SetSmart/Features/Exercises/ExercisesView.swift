import SwiftUI

struct ExercisesView: View {
    @State private var exercises: [Exercise] = []
    @State private var searchText = ""
    @State private var muscleFilter: MuscleGroup? = nil
    @State private var isLoading = false
    @State private var showCreate = false
    @State private var editingExercise: Exercise? = nil

    private let repo = ExerciseRepository()

    private var filtered: [Exercise] {
        exercises.filter {
            (muscleFilter == nil || $0.muscleGroup == muscleFilter) &&
            (searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText))
        }
    }

    var body: some View {
        List {
            ForEach(filtered) { exercise in
                ExerciseRowView(exercise: exercise)
                    .contentShape(Rectangle())
                    .onTapGesture { if !exercise.isBuiltIn { editingExercise = exercise } }
                    .listRowBackground(Color.ssSurface)
            }

            if filtered.isEmpty && !isLoading {
                Text("No exercises found")
                    .foregroundStyle(Color.ssTextMuted)
                    .listRowBackground(Color.ssBackground)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.ssBackground.ignoresSafeArea())
        .searchable(text: $searchText, prompt: "Search exercises")
        .navigationTitle("Exercises")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Button("All muscles") { muscleFilter = nil }
                    ForEach(MuscleGroup.allCases) { group in
                        Button(group.rawValue) { muscleFilter = group }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .foregroundStyle(muscleFilter != nil ? Color.ssAccent : Color.ssTextSecondary)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { showCreate = true } label: {
                    Image(systemName: "plus").foregroundStyle(Color.ssAccent)
                }
            }
        }
        .sheet(isPresented: $showCreate, onDismiss: refresh) {
            NavigationStack { ExerciseFormView() }
        }
        .sheet(item: $editingExercise, onDismiss: refresh) { exercise in
            NavigationStack { ExerciseFormView(exercise: exercise) }
        }
        .task { await load() }
    }

    private func refresh() { Task { await load() } }

    @MainActor
    private func load() async {
        isLoading = true
        exercises = (try? await repo.listExercises()) ?? []
        isLoading = false
    }
}

private struct ExerciseRowView: View {
    let exercise: Exercise

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(exercise.name).foregroundStyle(Color.ssTextPrimary)
                if !exercise.isBuiltIn {
                    Image(systemName: "person.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.ssAccent)
                }
            }
            Text("\(exercise.muscleGroup.rawValue) · \(exercise.equipment.rawValue)")
                .font(.caption)
                .foregroundStyle(Color.ssTextMuted)
        }
        .padding(.vertical, 4)
    }
}
