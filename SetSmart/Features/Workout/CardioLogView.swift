import SwiftUI

struct CardioLogView: View {
    @Environment(AppState.self) private var appState

    @State private var hours: Int   = 0
    @State private var minutes: Int = 0
    @State private var seconds: Int = 0

    private enum DistanceInputMode: Hashable { case distance, paceOrSpeed }
    @State private var distanceInputMode: DistanceInputMode = .distance
    @State private var distanceText: String  = ""
    @State private var paceMinText:  String  = ""
    @State private var paceSecText:  String  = ""

    @State private var effort: CardioEffort? = nil
    @State private var bodyWeights: [BodyWeight] = []
    @State private var isSaving  = false
    @State private var saveError: String? = nil

    private let bwRepo = BodyWeightRepository()

    // MARK: - Convenience (optional — phase changes after logCardio triggers one more re-render)

    private var timer: CardioTimer? {
        guard let w = appState.activeWorkout, case .cardio(let t) = w.phase, t.hasEnded else { return nil }
        return t
    }

    private var exercise: WorkoutExercise? {
        guard let t = timer else { return nil }
        return appState.activeWorkout?.exercises[t.exerciseIndex]
    }

    private var plan: CardioPlan?        { exercise?.cardio }
    private var activity: CardioActivity { plan?.activity ?? .other }
    private var weightUnit: WeightUnit   { appState.weightUnit }
    private var energyUnit: EnergyUnit   { appState.energyUnit }

    private var durationS: Int { max(0, hours * 3600 + minutes * 60 + seconds) }

    // MARK: - Derived distance

    private var distanceM: Double? {
        switch distanceInputMode {
        case .distance:
            guard let v = Double(distanceText), v > 0 else { return nil }
            return distanceToMetres(value: v, activity: activity, weightUnit: weightUnit)
        case .paceOrSpeed:
            return distanceFromPaceInput
        }
    }

    private var distanceFromPaceInput: Double? {
        guard durationS > 0 else { return nil }
        if activity == .cycle || activity == .indoor_cycle {
            guard let speed = Double(paceMinText), speed > 0 else { return nil }
            let kmh = weightUnit == .lb ? speed * 1.609344 : speed
            return (kmh / 3.6) * Double(durationS)
        }
        let m = Int(paceMinText) ?? 0
        let s = Int(paceSecText) ?? 0
        let paceS = m * 60 + s
        guard paceS > 0 else { return nil }
        let unitM: Double
        switch activity {
        case .swim: unitM = 100.0
        case .row:  unitM = 500.0
        default:    unitM = weightUnit == .lb ? 1609.344 : 1000.0
        }
        return (Double(durationS) / Double(paceS)) * unitM
    }

    // MARK: - Effort visibility

    private var showEffortPicker: Bool {
        guard effortOptions(for: activity).count > 1 else { return false }
        let speedSetsMet = activity.hasSpeedTable && (distanceM ?? 0) > 0 && durationS > 0
        return !speedSetsMet
    }

    // MARK: - Energy estimate

    private var energyEstimateText: String? {
        guard let profile = appState.profile, let timer, durationS > 0 else { return nil }
        let est = estimateCardioEnergy(
            activity:  activity,
            customMet: plan?.customMet,
            durationS: durationS,
            distanceM: distanceM,
            effort:    effort,
            startedAt: timer.startedAt,
            weights:   bodyWeights,
            profile:   profile
        )
        guard case .result(let r) = est else { return nil }
        if energyUnit == .kj {
            return "≈ \(Int((r.kcal * 4.184).rounded())) kJ above resting"
        }
        return "≈ \(Int(r.kcal.rounded())) kcal above resting"
    }

    private var canSave: Bool { durationS > 0 && !isSaving }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Guard: phase may already have changed by the time this re-renders
                    if timer != nil {
                        header
                        timeSection
                        if activity.hasDistance { distanceSection }
                        if showEffortPicker     { effortSection }
                        if let est = energyEstimateText { energyRow(est) }
                        if let err = saveError {
                            Text(err).font(.caption).foregroundStyle(Color.ssDanger)
                        }
                        saveButton
                        resumeLink
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(Color.ssBackground.ignoresSafeArea())
            .navigationTitle(appState.activeWorkout?.name ?? "")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear { setUp() }
        .task { bodyWeights = (try? await bwRepo.listBodyWeights()) ?? [] }
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(spacing: 8) {
            Text("DONE")
                .font(.caption.weight(.bold))
                .tracking(2)
                .foregroundStyle(Color.ssAccent)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Color.ssAccent.opacity(0.15))
                .clipShape(Capsule())
            Text(exercise?.name ?? "")
                .font(.title3.weight(.bold))
                .foregroundStyle(Color.ssTextPrimary)
        }
    }

    private var timeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("DURATION")
                .font(.caption.weight(.semibold)).tracking(1)
                .foregroundStyle(Color.ssTextMuted)

            HStack(spacing: 10) {
                timeField(label: "h",   value: $hours,   max: 23)
                Text(":").font(.title2.weight(.bold)).foregroundStyle(Color.ssTextMuted)
                timeField(label: "min", value: $minutes, max: 59)
                Text(":").font(.title2.weight(.bold)).foregroundStyle(Color.ssTextMuted)
                timeField(label: "s",   value: $seconds, max: 59)
            }
        }
        .padding(16)
        .background(Color.ssSurface)
        .cornerRadius(12)
    }

    private func timeField(label: String, value: Binding<Int>, max maxVal: Int) -> some View {
        VStack(spacing: 4) {
            TextField("0", value: value, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.title2.weight(.semibold).monospacedDigit())
                .foregroundStyle(Color.ssTextPrimary)
                .frame(width: 58)
                .padding(10)
                .background(Color.ssBackground)
                .cornerRadius(10)
                .onChange(of: value.wrappedValue) { _, v in
                    if v < 0       { value.wrappedValue = 0 }
                    if v > maxVal  { value.wrappedValue = maxVal }
                }
            Text(label).font(.caption2).foregroundStyle(Color.ssTextMuted)
        }
    }

    private var distanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            let paceLabel = (activity == .cycle || activity == .indoor_cycle) ? "Speed" : "Pace"
            Picker("", selection: $distanceInputMode) {
                Text("Distance").tag(DistanceInputMode.distance)
                Text(paceLabel).tag(DistanceInputMode.paceOrSpeed)
            }
            .pickerStyle(.segmented)

            switch distanceInputMode {
            case .distance:
                distanceInputField
                if let dm = distanceM, dm > 0, durationS > 0,
                   let pace = formatPace(distanceM: dm, durationS: durationS,
                                         activity: activity, weightUnit: weightUnit) {
                    Text(pace)
                        .font(.caption).foregroundStyle(Color.ssTextMuted)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            case .paceOrSpeed:
                paceOrSpeedField
                if let dm = distanceFromPaceInput, dm > 0 {
                    Text(formatDistanceDisplay(metres: dm, activity: activity, weightUnit: weightUnit))
                        .font(.caption).foregroundStyle(Color.ssTextMuted)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
        .padding(16)
        .background(Color.ssSurface)
        .cornerRadius(12)
    }

    private var distanceInputField: some View {
        HStack {
            TextField("0", text: $distanceText)
                .keyboardType(.decimalPad)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.ssTextPrimary)
            Text(distanceSuffix(activity: activity, weightUnit: weightUnit))
                .foregroundStyle(Color.ssTextSecondary)
        }
        .padding(12)
        .background(Color.ssBackground)
        .cornerRadius(10)
    }

    @ViewBuilder
    private var paceOrSpeedField: some View {
        if activity == .cycle || activity == .indoor_cycle {
            let speedUnit = weightUnit == .lb ? "mph" : "km/h"
            HStack {
                TextField("0", text: $paceMinText)
                    .keyboardType(.decimalPad)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.ssTextPrimary)
                Text(speedUnit).foregroundStyle(Color.ssTextSecondary)
            }
            .padding(12)
            .background(Color.ssBackground)
            .cornerRadius(10)
        } else {
            let unitLabel = activity == .swim ? "/ 100 m"
                          : activity == .row  ? "/ 500 m"
                          : weightUnit == .lb  ? "/ mi"
                          : "/ km"
            HStack(spacing: 8) {
                TextField("0", text: $paceMinText)
                    .keyboardType(.numberPad)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(Color.ssTextPrimary)
                    .frame(width: 48)
                Text(":").font(.title3.weight(.bold)).foregroundStyle(Color.ssTextMuted)
                TextField("00", text: $paceSecText)
                    .keyboardType(.numberPad)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(Color.ssTextPrimary)
                    .frame(width: 48)
                Text(unitLabel).foregroundStyle(Color.ssTextSecondary)
            }
            .padding(12)
            .background(Color.ssBackground)
            .cornerRadius(10)
        }
    }

    private var effortSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("HOW HARD WAS IT?")
                .font(.caption.weight(.semibold)).tracking(1)
                .foregroundStyle(Color.ssTextMuted)

            HStack(spacing: 8) {
                ForEach(effortOptions(for: activity), id: \.effort) { opt in
                    Button {
                        effort = effort == opt.effort ? nil : opt.effort
                    } label: {
                        Text(opt.label)
                            .font(.subheadline)
                            .padding(.horizontal, 14).padding(.vertical, 9)
                            .background(effort == opt.effort ? Color.ssAccent : Color.ssBackground)
                            .foregroundStyle(effort == opt.effort ? Color.black : Color.ssTextSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }

            Text("If you don't choose, the middle option is used.")
                .font(.caption).foregroundStyle(Color.ssTextMuted)
        }
        .padding(16)
        .background(Color.ssSurface)
        .cornerRadius(12)
    }

    private func energyRow(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "flame.fill").foregroundStyle(Color.ssAccent)
            Text("Estimated energy: \(text)")
                .font(.subheadline).foregroundStyle(Color.ssTextSecondary)
            Spacer()
        }
        .padding(14)
        .background(Color.ssSurface)
        .cornerRadius(12)
    }

    private var saveButton: some View {
        Button { save() } label: {
            Text("Save \(exercise?.name ?? "")")
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(!canSave)
    }

    private var resumeLink: some View {
        Button {
            appState.applyWorkoutAction(.resumeCardio)
        } label: {
            Text("Ended too soon? Resume the timer")
                .font(.subheadline).foregroundStyle(Color.ssAccent)
        }
        .padding(.bottom, 8)
    }

    // MARK: - Helpers

    private func setUp() {
        guard let timer else { return }
        let total = timer.elapsedSeconds
        hours   = total / 3600
        minutes = (total % 3600) / 60
        seconds = total % 60
    }

    private func save() {
        guard durationS > 0 else { return }
        isSaving = true; saveError = nil
        appState.applyWorkoutAction(.logCardio(
            durationS: durationS,
            distanceM: distanceM,
            effort:    effort
        ))
        isSaving = false
    }
}
