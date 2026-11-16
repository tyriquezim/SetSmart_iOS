import SwiftUI
import UserNotifications
import UIKit

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var displayName = ""
    @State private var weightUnit: WeightUnit = .kg
    @State private var energyUnit: EnergyUnit = .kj
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showSignOutConfirm = false
    @State private var showForgotPassword = false

    // Body details
    @State private var heightCmInput  = ""
    @State private var heightFeetInput = ""
    @State private var heightInchesInput = ""
    @State private var birthYearInput = ""
    @State private var selectedSex: Sex? = nil
    @State private var selectedActivity: DailyActivity? = nil
    @State private var selectedEffort: WorkoutEffort = .moderate
    @State private var isSavingBody = false
    @State private var bodyError: String?
    @State private var bodySaved = false
    @State private var showFullExplanation = false

    // Rest timer settings (device-only, UserDefaults)
    @State private var alarmSoundEnabled     = WorkoutSettings.shared.alarmSoundEnabled
    @State private var hapticsEnabled        = WorkoutSettings.shared.hapticsEnabled
    @State private var countdownBeepsEnabled = WorkoutSettings.shared.countdownBeepsEnabled
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined

    var body: some View {
        List {
            Section("Profile") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Display name")
                        .font(.caption)
                        .foregroundStyle(Color.ssTextSecondary)
                    SSTextField(placeholder: "Your name", text: $displayName)
                }
                .listRowBackground(Color.ssSurface)
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
            }

            Section("Units") {
                Picker("Weight", selection: $weightUnit) {
                    ForEach(WeightUnit.allCases, id: \.self) { unit in
                        Text(unit.label).tag(unit)
                    }
                }
                .foregroundStyle(Color.ssTextPrimary)
                .tint(Color.ssAccent)
                .listRowBackground(Color.ssSurface)

                Picker("Energy", selection: $energyUnit) {
                    ForEach(EnergyUnit.allCases, id: \.self) { unit in
                        Text(unit.label).tag(unit)
                    }
                }
                .foregroundStyle(Color.ssTextPrimary)
                .tint(Color.ssAccent)
                .listRowBackground(Color.ssSurface)
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(Color.ssDanger)
                        .listRowBackground(Color.ssSurface)
                }
            }

            bodyDetailsSection

            Section {
                Button(action: saveProfile) {
                    HStack(spacing: 8) {
                        if isSaving { ProgressView().tint(.black) }
                        Text("Save changes")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isSaving)
                .listRowBackground(Color.ssBackground)
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
            }

            Section("Rest Timer Alerts") {
                Toggle("Alarm sound", isOn: $alarmSoundEnabled)
                    .tint(Color.ssAccent)
                    .onChange(of: alarmSoundEnabled)     { _, v in WorkoutSettings.shared.alarmSoundEnabled     = v }
                Toggle("3-2-1 countdown beeps", isOn: $countdownBeepsEnabled)
                    .tint(Color.ssAccent)
                    .onChange(of: countdownBeepsEnabled) { _, v in WorkoutSettings.shared.countdownBeepsEnabled = v }
                Toggle("Haptics", isOn: $hapticsEnabled)
                    .tint(Color.ssAccent)
                    .onChange(of: hapticsEnabled)        { _, v in WorkoutSettings.shared.hapticsEnabled        = v }

                Button("Test alarm") { AlarmService.shared.play() }
                    .foregroundStyle(Color.ssAccent)

                notificationStatusRow
            }
            .listRowBackground(Color.ssSurface)
            .foregroundStyle(Color.ssTextPrimary)

            Section("Account") {
                Button("Change password") { showForgotPassword = true }
                    .foregroundStyle(Color.ssAccent)
                    .listRowBackground(Color.ssSurface)

                Button("Sign out") { showSignOutConfirm = true }
                    .foregroundStyle(Color.ssDanger)
                    .listRowBackground(Color.ssSurface)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.ssBackground.ignoresSafeArea())
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadFromProfile()
            Task {
                let s = await UNUserNotificationCenter.current().notificationSettings()
                notificationStatus = s.authorizationStatus
            }
        }
        .confirmationDialog("Sign out?", isPresented: $showSignOutConfirm, titleVisibility: .visible) {
            Button("Sign out", role: .destructive) { signOut() }
        } message: {
            Text("You'll need to sign back in to access your workouts.")
        }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView()
        }
        .sheet(isPresented: $showFullExplanation) {
            FullExplanationSheet(energyUnit: appState.energyUnit)
        }
    }

    @ViewBuilder
    private var notificationStatusRow: some View {
        switch notificationStatus {
        case .authorized, .provisional, .ephemeral:
            Label("Notifications allowed", systemImage: "checkmark.circle.fill")
                .foregroundStyle(Color.ssChartSeries)
                .font(.subheadline)
        case .denied:
            VStack(alignment: .leading, spacing: 8) {
                Label("Notifications are off", systemImage: "bell.slash.fill")
                    .foregroundStyle(Color.ssWarningText)
                    .font(.subheadline)
                Text("Rest timer alerts won't appear when the app is in the background.")
                    .font(.caption)
                    .foregroundStyle(Color.ssTextMuted)
                Button("Open Settings to allow notifications") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .foregroundStyle(Color.ssAccent)
                .font(.subheadline)
            }
            .padding(.vertical, 4)
        default:
            Button("Allow rest timer notifications") {
                NotificationService.shared.requestPermission()
                Task {
                    try? await Task.sleep(for: .milliseconds(500))
                    let s = await UNUserNotificationCenter.current().notificationSettings()
                    notificationStatus = s.authorizationStatus
                }
            }
            .foregroundStyle(Color.ssAccent)
        }
    }

    // MARK: - Body details section

    private var bodyDetailsSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Text("Used only to estimate how much energy you burn. Weight and body fat % come from your latest weigh-in.")
                    .font(.caption)
                    .foregroundStyle(Color.ssTextMuted)
            }
            .listRowBackground(Color.ssSurface)

            // Height
            if weightUnit == .lb {
                HStack(spacing: 8) {
                    Text("Height")
                        .foregroundStyle(Color.ssTextPrimary)
                    Spacer()
                    TextField("ft", text: $heightFeetInput)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 44)
                    Text("ft")
                        .foregroundStyle(Color.ssTextMuted)
                    TextField("in", text: $heightInchesInput)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 44)
                    Text("in")
                        .foregroundStyle(Color.ssTextMuted)
                }
                .listRowBackground(Color.ssSurface)
            } else {
                HStack {
                    Text("Height (cm)")
                        .foregroundStyle(Color.ssTextPrimary)
                    Spacer()
                    TextField("e.g. 180", text: $heightCmInput)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }
                .listRowBackground(Color.ssSurface)
            }

            // Birth year
            HStack {
                Text("Birth year")
                    .foregroundStyle(Color.ssTextPrimary)
                Spacer()
                TextField("e.g. 1995", text: $birthYearInput)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
            }
            .listRowBackground(Color.ssSurface)

            if let yr = Int(birthYearInput),
               Calendar.current.component(.year, from: Date()) - yr < 18 {
                Text("These equations were developed for adults, so estimates are less reliable under 18.")
                    .font(.caption)
                    .foregroundStyle(Color.ssTextMuted)
                    .listRowBackground(Color.ssSurface)
            }

            // Sex
            VStack(alignment: .leading, spacing: 8) {
                Text("Sex for resting energy")
                    .font(.subheadline)
                    .foregroundStyle(Color.ssTextSecondary)
                Picker("Sex", selection: $selectedSex) {
                    Text("Not set").tag(Sex?.none)
                    Text("Male").tag(Sex?.some(.male))
                    Text("Female").tag(Sex?.some(.female))
                }
                .pickerStyle(.segmented)
                Text("Used by Mifflin-St Jeor. Not needed once you've logged a body fat %.")
                    .font(.caption)
                    .foregroundStyle(Color.ssTextMuted)
            }
            .listRowBackground(Color.ssSurface)
            .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))

            // Daily activity
            VStack(alignment: .leading, spacing: 8) {
                Text("Everyday activity, outside workouts")
                    .font(.subheadline)
                    .foregroundStyle(Color.ssTextSecondary)
                ForEach(DailyActivity.allCases, id: \.self) { activity in
                    Button { selectedActivity = activity } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(activity.label)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Color.ssTextPrimary)
                                Text(activity.hint)
                                    .font(.caption)
                                    .foregroundStyle(Color.ssTextMuted)
                            }
                            Spacer()
                            if selectedActivity == activity {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.ssAccent)
                            }
                        }
                        .padding(12)
                        .background(selectedActivity == activity ? Color.ssSurfaceRaised : Color.ssBackground)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(
                            selectedActivity == activity ? Color.ssAccent.opacity(0.5) : Color.ssBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .listRowBackground(Color.ssSurface)
            .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))

            // Workout effort
            VStack(alignment: .leading, spacing: 8) {
                Text("Typical workout effort")
                    .font(.subheadline)
                    .foregroundStyle(Color.ssTextSecondary)
                ForEach(WorkoutEffort.allCases, id: \.self) { effort in
                    Button { selectedEffort = effort } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(effort.label)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Color.ssTextPrimary)
                                Text(effort.hint)
                                    .font(.caption)
                                    .foregroundStyle(Color.ssTextMuted)
                            }
                            Spacer()
                            if selectedEffort == effort {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.ssAccent)
                            }
                        }
                        .padding(12)
                        .background(selectedEffort == effort ? Color.ssSurfaceRaised : Color.ssBackground)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(
                            selectedEffort == effort ? Color.ssAccent.opacity(0.5) : Color.ssBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .listRowBackground(Color.ssSurface)
            .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))

            // Error / saved feedback
            if let err = bodyError {
                Text(err).font(.caption).foregroundStyle(Color.ssDanger)
                    .listRowBackground(Color.ssSurface)
            }

            // Save button + explanation link
            HStack {
                Button(action: saveBodyDetails) {
                    HStack(spacing: 8) {
                        if isSavingBody { ProgressView().tint(.black) }
                        Text(bodySaved ? "Saved." : "Save body details")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isSavingBody)
                Spacer()
                Button {
                    showFullExplanation = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "info.circle")
                        Text("How estimates work")
                    }
                    .font(.caption)
                    .foregroundStyle(Color.ssAccent)
                }
                .buttonStyle(.plain)
            }
            .listRowBackground(Color.ssBackground)
            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))

        } header: {
            Text("Body details")
        }
    }

    private func saveBodyDetails() {
        // Validate height
        let heightCm: Double?
        if weightUnit == .lb {
            let ft = Double(heightFeetInput) ?? 0
            let inches = Double(heightInchesInput) ?? 0
            let cm = (ft * 12 + inches) * 2.54
            if !heightFeetInput.isEmpty || !heightInchesInput.isEmpty {
                if cm < 50 || cm > 272 {
                    bodyError = "Enter a height between 50 and 272 cm (1 ft 8 in – 8 ft 11 in)."
                    return
                }
                heightCm = (cm * 10).rounded() / 10
            } else {
                heightCm = nil
            }
        } else {
            if !heightCmInput.isEmpty {
                guard let v = Double(heightCmInput), v >= 50, v <= 272 else {
                    bodyError = "Enter a height between 50 and 272 cm."
                    return
                }
                heightCm = v
            } else {
                heightCm = nil
            }
        }

        let birthYear: Int?
        if !birthYearInput.isEmpty {
            guard let yr = Int(birthYearInput), yr >= 1900, yr <= Calendar.current.component(.year, from: Date()) else {
                bodyError = "Enter a valid birth year."
                return
            }
            birthYear = yr
        } else {
            birthYear = nil
        }

        bodyError = nil; isSavingBody = true; bodySaved = false
        Task {
            do {
                try await appState.updateBodyDetails(
                    heightCm:      heightCm,
                    birthYear:     birthYear,
                    sex:           selectedSex,
                    dailyActivity: selectedActivity,
                    workoutEffort: selectedEffort
                )
                bodySaved = true
                try? await Task.sleep(for: .seconds(2))
                bodySaved = false
            } catch {
                bodyError = error.localizedDescription
            }
            isSavingBody = false
        }
    }

    private func loadFromProfile() {
        guard let profile = appState.profile else { return }
        displayName = profile.displayName ?? ""
        weightUnit  = profile.weightUnit
        energyUnit  = profile.energyUnit
        // Body details
        selectedSex      = profile.sex
        selectedActivity = profile.dailyActivity
        selectedEffort   = profile.workoutEffort
        if let cm = profile.heightCm {
            if profile.weightUnit == .lb {
                let totalInches = cm / 2.54
                heightFeetInput   = "\(Int(totalInches / 12))"
                heightInchesInput = String(format: "%.1f", totalInches.truncatingRemainder(dividingBy: 12))
            } else {
                heightCmInput = String(format: "%.1f", cm)
            }
        }
        if let by = profile.birthYear { birthYearInput = "\(by)" }
    }

    private func saveProfile() {
        isSaving = true
        errorMessage = nil
        Task {
            do {
                try await appState.updateProfile(
                    displayName: displayName.isEmpty ? nil : displayName,
                    weightUnit: weightUnit,
                    energyUnit: energyUnit
                )
            } catch {
                errorMessage = error.localizedDescription
            }
            isSaving = false
        }
    }

    private func signOut() {
        Task { try? await appState.signOut() }
    }
}
