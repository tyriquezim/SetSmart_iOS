import SwiftUI

struct ExerciseFormView: View {
    var exercise: Exercise? = nil

    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var muscleGroup: MuscleGroup = .chest
    @State private var equipment: Equipment = .barbell
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showArchiveConfirm = false

    private let repo = ExerciseRepository()

    private var isEditing: Bool { exercise != nil }
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSaving }

    var body: some View {
        List {
            Section {
                SSTextField(placeholder: "Exercise name", text: $name)
                    .listRowBackground(Color.ssSurface)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            Section("Muscle group") {
                Picker("Muscle group", selection: $muscleGroup) {
                    ForEach(MuscleGroup.allCases) { group in
                        Text(group.rawValue).tag(group)
                    }
                }
                .foregroundStyle(Color.ssTextPrimary)
                .tint(Color.ssAccent)
                .listRowBackground(Color.ssSurface)
            }

            Section("Equipment") {
                Picker("Equipment", selection: $equipment) {
                    ForEach(Equipment.allCases, id: \.self) { eq in
                        Text(eq.rawValue).tag(eq)
                    }
                }
                .foregroundStyle(Color.ssTextPrimary)
                .tint(Color.ssAccent)
                .listRowBackground(Color.ssSurface)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(Color.ssDanger)
                    .listRowBackground(Color.ssBackground)
            }

            Section {
                Button(action: save) {
                    HStack(spacing: 8) {
                        if isSaving { ProgressView().tint(.black) }
                        Text(isEditing ? "Save changes" : "Create exercise")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!canSave)
                .listRowBackground(Color.ssBackground)
                .listRowInsets(.init())
            }

            if isEditing {
                Section {
                    Button("Archive exercise") { showArchiveConfirm = true }
                        .foregroundStyle(Color.ssDanger)
                        .listRowBackground(Color.ssSurface)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.ssBackground.ignoresSafeArea())
        .navigationTitle(isEditing ? exercise!.name : "New exercise")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }.foregroundStyle(Color.ssAccent)
            }
        }
        .onAppear {
            guard let ex = exercise else { return }
            name        = ex.name
            muscleGroup = ex.muscleGroup
            equipment   = ex.equipment
        }
        .confirmationDialog("Archive exercise?", isPresented: $showArchiveConfirm, titleVisibility: .visible) {
            Button("Archive", role: .destructive) { archive() }
        } message: {
            Text("The exercise will be hidden. Past workouts won't be affected.")
        }
    }

    private func save() {
        isSaving = true
        errorMessage = nil
        Task {
            do {
                if var ex = exercise {
                    ex.name        = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    ex.muscleGroup = muscleGroup
                    ex.equipment   = equipment
                    try await repo.updateExercise(ex)
                } else {
                    _ = try await repo.createExercise(name: name, muscleGroup: muscleGroup, equipment: equipment)
                }
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSaving = false
        }
    }

    private func archive() {
        guard let ex = exercise else { return }
        Task {
            try? await repo.archiveExercise(id: ex.id)
            dismiss()
        }
    }
}
