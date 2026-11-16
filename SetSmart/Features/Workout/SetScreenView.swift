import SwiftUI

struct SetScreenView: View {
    @Environment(AppState.self) private var appState

    @State private var reps: Int      = 8
    @State private var weight: Double = 0
    @State private var showDiscard    = false

    private var workout: WorkoutState { appState.activeWorkout! }
    private var currentIdx: Int? { workout.queue.first }
    private var currentEx: WorkoutExercise? { currentIdx.map { workout.exercises[$0] } }
    private var info: CurrentSetInfo? { workout.currentSet }
    private var unit: WeightUnit { appState.weightUnit }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                headerRow.padding(.horizontal)
                Divider().background(Color.ssBorder)
                ScrollView {
                    VStack(spacing: 24) {
                        exerciseTitle
                        setCountRow
                        stepperSection
                        logButton
                        loggedSetsList
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
            }
            .background(Color.ssBackground)
            .navigationBarHidden(true)
        }
        .onAppear { prefill() }
        .onChange(of: workout.queue.first) { prefill() }
        .confirmationDialog("Discard workout?", isPresented: $showDiscard, titleVisibility: .visible) {
            Button("Discard", role: .destructive) { appState.discardWorkout() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your progress will be lost.")
        }
    }

    // MARK: - Subviews

    private var headerRow: some View {
        HStack {
            Button { appState.isWorkoutPlayerVisible = false } label: {
                Image(systemName: "chevron.down")
                    .font(.title3)
                    .foregroundStyle(Color.ssTextSecondary)
            }
            Spacer()
            Text(workout.name)
                .font(.headline)
            Spacer()
            Menu {
                Button { appState.applyWorkoutAction(.skipExercise) } label: {
                    Label("Skip exercise", systemImage: "forward.fill")
                }
                Button(role: .destructive) { showDiscard = true } label: {
                    Label("Discard workout", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundStyle(Color.ssTextSecondary)
            }
        }
        .padding(.vertical, 12)
    }

    private var exerciseTitle: some View {
        VStack(spacing: 4) {
            if let ex = currentEx {
                Text(ex.name)
                    .font(.title2.weight(.bold))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var setCountRow: some View {
        HStack {
            if let ex = currentEx {
                let logged = ex.logged.count
                let total  = ex.sets.count
                Text("Set \(logged + 1) of \(total)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.ssAccent)
                Spacer()
                Text("Exercise \(workout.performedOrder.count + 1) of \(workout.exercises.count)")
                    .font(.subheadline)
                    .foregroundStyle(Color.ssTextSecondary)
            }
        }
    }

    private var stepperSection: some View {
        VStack(spacing: 20) {
            StepperRow(label: "Reps", value: $reps, step: 1, range: 1...999,
                       format: { "\($0)" })
            StepperRow(label: "Weight (\(unit.rawValue))", value: $weight,
                       step: unit.stepSize, range: 0...(999),
                       format: { String(format: "%g", $0) })
        }
        .padding(20)
        .background(Color.ssSurface)
        .cornerRadius(16)
    }

    private var logButton: some View {
        Button {
            let kg = unit.toKg(weight)
            appState.applyWorkoutAction(.logSet(reps: reps, weightKg: kg <= 0 ? nil : kg))
            HapticsService.loggedSet()
        } label: {
            Text("Complete Set")
                .frame(maxWidth: .infinity)
                .frame(height: 64)
        }
        .buttonStyle(PrimaryButtonStyle())
    }

    private var loggedSetsList: some View {
        Group {
            if let ex = currentEx, !ex.logged.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Logged")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.ssTextSecondary)
                    ForEach(ex.logged.indices, id: \.self) { i in
                        let s = ex.logged[i]
                        HStack {
                            Text("Set \(i + 1)")
                                .foregroundStyle(Color.ssTextSecondary)
                            Spacer()
                            Text("\(s.reps) reps")
                            if let w = s.weightKg {
                                Text("· \(String(format: "%g", unit.fromKg(w))) \(unit.rawValue)")
                                    .foregroundStyle(Color.ssTextSecondary)
                            }
                        }
                        .font(.subheadline)
                    }
                }
                .padding(16)
                .background(Color.ssSurface)
                .cornerRadius(12)
            }
        }
    }

    private func prefill() {
        guard let info else { return }
        reps   = info.prefillReps
        weight = unit.fromKg(info.prefillWeightKg ?? 0)
    }
}

// MARK: - StepperRow

private struct StepperRow: View {
    let label: String
    @Binding var value: Double
    let step: Double
    let range: ClosedRange<Double>
    let format: (Double) -> String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Color.ssTextSecondary)
            Spacer()
            Button { value = max(range.lowerBound, value - step) } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.ssAccent)
            }
            Text(format(value))
                .font(.title2.weight(.bold))
                .frame(minWidth: 60, alignment: .center)
            Button { value = min(range.upperBound, value + step) } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.ssAccent)
            }
        }
    }

    init(label: String, value: Binding<Double>, step: Double, range: ClosedRange<Double>,
         format: @escaping (Double) -> String) {
        self.label  = label
        _value      = value
        self.step   = step
        self.range  = range
        self.format = format
    }
}

extension StepperRow {
    init(label: String, value: Binding<Int>, step: Int, range: ClosedRange<Int>,
         format: @escaping (Int) -> String) {
        self.init(
            label: label,
            value: Binding(get: { Double(value.wrappedValue) },
                           set: { value.wrappedValue = Int($0) }),
            step: Double(step),
            range: Double(range.lowerBound)...Double(range.upperBound),
            format: { format(Int($0)) }
        )
    }
}
