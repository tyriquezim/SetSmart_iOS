import SwiftUI

struct RoutineExerciseEditorView: View {
    @Binding var exercise: EditableRoutineExercise
    let weightUnit: WeightUnit

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section("Rest time") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(restPresets, id: \.self) { preset in
                            Button(formatRestSeconds(preset)) {
                                exercise.restSeconds = preset
                            }
                            .font(.subheadline.weight(exercise.restSeconds == preset ? .bold : .regular))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(exercise.restSeconds == preset ? Color.ssAccent : Color.ssSurfaceRaised)
                            .foregroundStyle(exercise.restSeconds == preset ? Color.black : Color.ssTextSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .padding(.vertical, 2)
                }
                .listRowBackground(Color.ssSurface)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            Section {
                ForEach(exercise.sets.indices, id: \.self) { idx in
                    SetEditorRow(
                        setNumber: idx + 1,
                        set: $exercise.sets[idx],
                        weightUnit: weightUnit
                    )
                    .listRowBackground(Color.ssSurface)
                }
                .onDelete { idx in exercise.sets.remove(atOffsets: idx) }

                Button {
                    let last = exercise.sets.last
                    exercise.sets.append(EditablePlannedSet(reps: last?.reps ?? 10, weightKg: last?.weightKg))
                } label: {
                    Label("Add set", systemImage: "plus.circle.fill")
                        .foregroundStyle(Color.ssAccent)
                }
                .listRowBackground(Color.ssSurface)
            } header: {
                HStack {
                    Text("SETS")
                    Spacer()
                    EditButton().font(.caption).foregroundStyle(Color.ssAccent)
                }
            }

            Section("Notes") {
                SSTextField(placeholder: "Exercise notes (optional)", text: $exercise.notes)
                    .listRowBackground(Color.ssSurface)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.ssBackground.ignoresSafeArea())
        .navigationTitle(exercise.exerciseName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }.foregroundStyle(Color.ssAccent)
            }
        }
    }
}

private struct SetEditorRow: View {
    let setNumber: Int
    @Binding var set: EditablePlannedSet
    let weightUnit: WeightUnit

    var body: some View {
        HStack(spacing: 0) {
            Text("Set \(setNumber)")
                .font(.caption)
                .foregroundStyle(Color.ssTextMuted)
                .frame(width: 44, alignment: .leading)

            Spacer()

            // Reps stepper
            HStack(spacing: 6) {
                Text("Reps").font(.caption).foregroundStyle(Color.ssTextSecondary)
                stepperButton(systemName: "minus.circle.fill") {
                    if set.reps > 0 { set.reps -= 1 }
                }
                Text("\(set.reps)")
                    .font(.body.monospacedDigit().weight(.semibold))
                    .foregroundStyle(Color.ssTextPrimary)
                    .frame(width: 28, alignment: .center)
                stepperButton(systemName: "plus.circle.fill", accent: true) { set.reps += 1 }
            }

            Divider().padding(.horizontal, 12)

            // Weight stepper
            HStack(spacing: 6) {
                Text(weightUnit.label).font(.caption).foregroundStyle(Color.ssTextSecondary)
                stepperButton(systemName: "minus.circle.fill") {
                    let cur = set.weightKg ?? 0
                    let newVal = max(0, weightUnit.fromKg(cur) - weightUnit.stepSize)
                    set.weightKg = newVal <= 0 ? nil : weightUnit.toKg(newVal)
                }
                Text(weightText)
                    .font(.body.monospacedDigit().weight(.semibold))
                    .foregroundStyle(Color.ssTextPrimary)
                    .frame(width: 44, alignment: .center)
                stepperButton(systemName: "plus.circle.fill", accent: true) {
                    let cur = set.weightKg ?? 0
                    set.weightKg = weightUnit.toKg(weightUnit.fromKg(cur) + weightUnit.stepSize)
                }
            }
        }
        .padding(.vertical, 6)
    }

    private var weightText: String {
        guard let kg = set.weightKg, kg > 0 else { return "—" }
        return String(format: "%.1f", weightUnit.fromKg(kg))
    }

    private func stepperButton(systemName: String, accent: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .foregroundStyle(accent ? Color.ssAccent : Color.ssTextSecondary)
                .font(.title3)
        }
        .buttonStyle(.plain)
    }
}
