import SwiftUI

struct ExercisePickerView: View {
    let onSelect: (Exercise) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var exercises: [Exercise] = []
    @State private var searchText = ""
    @State private var muscleFilter: MuscleGroup? = nil
    @State private var showCreate = false

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
                Button {
                    onSelect(exercise)
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(exercise.name).foregroundStyle(Color.ssTextPrimary)
                            Text("\(exercise.muscleGroup.rawValue) · \(exercise.equipment.rawValue)")
                                .font(.caption).foregroundStyle(Color.ssTextMuted)
                        }
                        Spacer()
                        Image(systemName: "plus.circle").foregroundStyle(Color.ssAccent)
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(Color.ssSurface)
            }

            if filtered.isEmpty {
                Text("No exercises found")
                    .foregroundStyle(Color.ssTextMuted)
                    .listRowBackground(Color.ssBackground)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.ssBackground.ignoresSafeArea())
        .searchable(text: $searchText, prompt: "Search exercises")
        .navigationTitle("Pick an exercise")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }.foregroundStyle(Color.ssAccent)
            }
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
        .sheet(isPresented: $showCreate, onDismiss: { Task { await load() } }) {
            NavigationStack { ExerciseFormView() }
        }
        .task { await load() }
    }

    @MainActor
    private func load() async {
        exercises = (try? await repo.listExercises()) ?? []
    }
}
