import SwiftUI

struct RoutineEditorView: View {
    var existingRoutine: Routine? = nil

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var draft = EditableRoutine()
    @State private var isSaving = false
    @State private var errorMessage: String? = nil
    @State private var showExercisePicker = false
    @State private var editingExerciseIndex: Int? = nil

    private let repo = RoutineRepository()

    private var canSave: Bool {
        !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSaving
    }

    var body: some View {
        List {
            // Routine name + notes
            Section {
                SSTextField(placeholder: "Routine name", text: $draft.name)
                    .listRowBackground(Color.ssSurface)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                SSTextField(placeholder: "Notes (optional)", text: $draft.notes)
                    .listRowBackground(Color.ssSurface)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            // Exercise list
            Section {
                ForEach(draft.exercises.indices, id: \.self) { idx in
                    Button { editingExerciseIndex = idx } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(draft.exercises[idx].exerciseName)
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(Color.ssTextPrimary)
                                Group {
                                    if draft.exercises[idx].isCardio {
                                        Text("Cardio · \(draft.exercises[idx].goalDescription)")
                                    } else {
                                        Text("\(draft.exercises[idx].setsDescription) · \(draft.exercises[idx].restDescription)")
                                    }
                                }
                                    .font(.caption)
                                    .foregroundStyle(Color.ssTextSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption).foregroundStyle(Color.ssTextMuted)
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(Color.ssSurface)
                }
                .onMove { from, to in draft.exercises.move(fromOffsets: from, toOffset: to) }
                .onDelete { idx in draft.exercises.remove(atOffsets: idx) }

                Button { showExercisePicker = true } label: {
                    Label("Add exercise", systemImage: "plus.circle.fill")
                        .foregroundStyle(Color.ssAccent)
                }
                .listRowBackground(Color.ssSurface)

            } header: {
                HStack {
                    Text("EXERCISES")
                    Spacer()
                    EditButton().font(.caption).foregroundStyle(Color.ssAccent)
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption).foregroundStyle(Color.ssDanger)
                    .listRowBackground(Color.ssBackground)
            }

            Section {
                Button(action: save) {
                    HStack(spacing: 8) {
                        if isSaving { ProgressView().tint(.black) }
                        Text("Save routine")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!canSave)
                .listRowBackground(Color.ssBackground)
                .listRowInsets(.init())
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.ssBackground.ignoresSafeArea())
        .navigationTitle(existingRoutine == nil ? "New routine" : "Edit routine")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }.foregroundStyle(Color.ssAccent)
            }
        }
        .sheet(isPresented: $showExercisePicker) {
            NavigationStack {
                ExercisePickerView { exercise in
                    draft.exercises.append(EditableRoutineExercise(exercise: exercise))
                }
            }
        }
        // Exercise detail sheet
        .sheet(
            isPresented: Binding(
                get: { editingExerciseIndex != nil },
                set: { if !$0 { editingExerciseIndex = nil } }
            )
        ) {
            if let idx = editingExerciseIndex, idx < draft.exercises.count {
                NavigationStack {
                    RoutineExerciseEditorView(
                        exercise: $draft.exercises[idx],
                        weightUnit: appState.weightUnit
                    )
                }
            }
        }
        .onAppear {
            if draft.name.isEmpty, let r = existingRoutine {
                draft = EditableRoutine(from: r)
            }
        }
    }

    private func save() {
        isSaving = true
        errorMessage = nil
        let exercises = draft.exercises.enumerated().map { (idx, ex) in
            SaveRoutineExercise(
                exercise_id:       ex.exerciseId,
                position:          idx,
                rest_seconds:      ex.restSeconds,
                sets:              ex.sets.map { SavePlannedSet(reps: $0.reps, weight_kg: $0.weightKg) },
                notes:             ex.notes.isEmpty ? nil : ex.notes,
                target_duration_s: ex.targetDurationMin.map { $0 * 60 }
            )
        }
        Task {
            do {
                _ = try await repo.saveRoutine(
                    id: existingRoutine?.id,
                    name: draft.name.trimmingCharacters(in: .whitespacesAndNewlines),
                    notes: draft.notes.isEmpty ? nil : draft.notes,
                    exercises: exercises
                )
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSaving = false
        }
    }
}
