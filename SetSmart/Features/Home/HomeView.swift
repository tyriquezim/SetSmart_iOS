import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) private var appState

    @State private var todayLogs: [FoodLog] = []
    @State private var targets: NutritionTargets?
    @State private var recentSessions: [WorkoutSessionSummary] = []
    @State private var weekWorkoutDays: Set<String> = []
    @State private var allBodyWeights: [BodyWeight] = []
    @State private var latestWeight: BodyWeight?
    @State private var hasWeightToday = false
    @State private var routines: [RoutineSummary] = []
    @State private var loadingRoutineId: UUID?

    private let foodRepo    = FoodRepository()
    private let workoutRepo = WorkoutRepository()
    private let bwRepo      = BodyWeightRepository()
    private let routineRepo = RoutineRepository()

    private var todayEnergy: Double { todayLogs.reduce(0) { $0 + $1.energyKj } }

    private var todayBurnResult: DayEnergyResult? {
        guard let profile = appState.profile, !allBodyWeights.isEmpty else { return nil }
        let todayStr = String.todayFoodDate()
        let slots = recentSessions
            .filter { localDayString(from: $0.startedAt) == todayStr }
            .map { (startedAt: $0.startedAt, finishedAt: Optional($0.startedAt.addingTimeInterval($0.duration))) }
        return estimateDayEnergy(day: todayStr, workouts: slots, weights: allBodyWeights, profile: profile)
    }

    // Formatter that converts a timestamptz Date → local calendar day string
    private static let localDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        return f
    }()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    greetingHeader
                    weekCard
                    bodyWeightCard
                    foodTodayCard
                    if !routines.isEmpty { routinesSection }
                    if !recentSessions.isEmpty { recentWorkoutsSection }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color.ssBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(Color.ssTextSecondary)
                    }
                }
            }
            .task { await refresh() }
            .refreshable { await refresh() }
        }
    }

    // MARK: - Greeting

    private var greetingHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greetingText)
                .font(.title3)
                .foregroundStyle(Color.ssTextSecondary)
            Text(appState.profile?.firstName ?? "Athlete")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(Color.ssTextPrimary)
        }
    }

    // MARK: - Last 7 days dots (Mon–Sun current week)

    private var weekCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("This Week", systemImage: "calendar")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.ssAccent)
                    Spacer()
                    let count = weekWorkoutDays.count
                    Text("\(count) workout\(count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(Color.ssTextSecondary)
                }
                HStack(spacing: 0) {
                    ForEach(currentWeekDays, id: \.dateStr) { day in
                        VStack(spacing: 6) {
                            Text(day.label)
                                .font(.caption2)
                                .foregroundStyle(Color.ssTextMuted)
                            Circle()
                                .foregroundStyle(weekWorkoutDays.contains(day.dateStr)
                                    ? Color.ssChartSeries : Color.ssBorder)
                                .frame(width: 10, height: 10)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(16)
        }
    }

    // MARK: - Body weight card

    private var bodyWeightCard: some View {
        CardView {
            Button { appState.selectedTab = 3 } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Body Weight", systemImage: "scalemass.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.ssAccent)
                        if let bw = latestWeight {
                            let display = bw.weightKg * appState.weightUnit.kgFactor
                            Text(String(format: "%.1f %@", display, appState.weightUnit.label))
                                .font(.title2.weight(.bold))
                                .foregroundStyle(Color.ssTextPrimary)
                                .monospacedDigit()
                        } else {
                            Text("No weight logged yet")
                                .font(.subheadline)
                                .foregroundStyle(Color.ssTextMuted)
                        }
                    }
                    Spacer()
                    if hasWeightToday {
                        Label("Logged today", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(Color.ssChartSeries)
                    } else {
                        Text("Log today →")
                            .font(.caption)
                            .foregroundStyle(Color.ssTextSecondary)
                    }
                }
                .padding(16)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Food today card

    private var foodTodayCard: some View {
        CardView {
            VStack(spacing: 0) {
            Button { appState.selectedTab = 2 } label: {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Today's Food", systemImage: "fork.knife")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.ssAccent)

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(formatEnergy(todayEnergy, unit: appState.energyUnit))
                            .font(.title2.weight(.bold))
                            .foregroundStyle(Color.ssTextPrimary)
                            .contentTransition(.numericText())
                            .monospacedDigit()
                        Text(appState.energyUnit.label)
                            .font(.subheadline)
                            .foregroundStyle(Color.ssTextSecondary)
                        Spacer()
                        if let target = targets?.energyKj, target > 0 {
                            Text("/ \(formatEnergy(target, unit: appState.energyUnit))")
                                .font(.caption)
                                .foregroundStyle(Color.ssTextMuted)
                        }
                    }

                    if let target = targets?.energyKj, target > 0 {
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule().foregroundStyle(Color.ssMeterTrack)
                                let f = min(todayEnergy / target, 1)
                                Capsule()
                                    .foregroundStyle(todayEnergy > target ? Color.ssWarning : Color.ssChartSeries)
                                    .frame(width: proxy.size.width * f)
                                    .animation(.easeOut(duration: 0.3), value: f)
                            }
                        }
                        .frame(height: 6)

                        let remaining = target - todayEnergy
                        if remaining >= 0 {
                            Text("\(formatEnergy(remaining, unit: appState.energyUnit)) \(appState.energyUnit.label) left · Add food →")
                                .font(.caption)
                                .foregroundStyle(Color.ssTextSecondary)
                        } else {
                            Label("Over by \(formatEnergy(-remaining, unit: appState.energyUnit)) \(appState.energyUnit.label)",
                                  systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(Color.ssWarningText)
                        }
                    } else {
                        Text("Add food →")
                            .font(.caption)
                            .foregroundStyle(Color.ssTextSecondary)
                    }

                    // Macros row
                    let p = todayLogs.reduce(0.0) { $0 + ($1.proteinG ?? 0) }
                    let c = todayLogs.reduce(0.0) { $0 + ($1.carbsG   ?? 0) }
                    let f = todayLogs.reduce(0.0) { $0 + ($1.fatG     ?? 0) }

                    HStack(spacing: 0) {
                        macroCol("P", value: p, target: targets?.proteinG)
                        macroCol("C", value: c, target: targets?.carbsG)
                        macroCol("F", value: f, target: targets?.fatG)
                    }
                }
                .padding(16)
            }
            .buttonStyle(.plain)

            if case .result(let c) = todayBurnResult {
                Divider().background(Color.ssBorder).padding(.horizontal, 16)
                HStack(spacing: 6) {
                    Text("Estimated burn today")
                        .font(.caption)
                        .foregroundStyle(Color.ssTextMuted)
                    Text(formatEnergyEstimate(c.totalKcal, unit: appState.energyUnit))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.ssTextSecondary)
                    InfoButton(content: .totalBurn(c), unit: appState.energyUnit)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            } // VStack
        }
    }

    @ViewBuilder
    private func macroCol(_ label: String, value: Double, target: Double?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(Color.ssTextMuted)
            if let t = target, t > 0 {
                Text("\(formatMacro(value)) / \(formatMacro(t)) g")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Color.ssTextSecondary)
            } else {
                Text("\(formatMacro(value)) g")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Color.ssTextSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Your routines (first 4 with play buttons)

    private var routinesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Your Routines")
                    .font(.headline)
                    .foregroundStyle(Color.ssTextPrimary)
                Spacer()
                Button("See all") { appState.selectedTab = 1 }
                    .font(.subheadline)
                    .foregroundStyle(Color.ssAccent)
            }
            ForEach(routines) { routine in
                CardView {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(routine.name)
                                .font(.body.weight(.medium))
                                .foregroundStyle(Color.ssTextPrimary)
                            Text("\(routine.exerciseCount) exercise\(routine.exerciseCount == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundStyle(Color.ssTextSecondary)
                        }
                        Spacer()
                        Button { playRoutine(routine) } label: {
                            Group {
                                if loadingRoutineId == routine.id {
                                    ProgressView().tint(Color.ssBackground).scaleEffect(0.8)
                                } else {
                                    Image(systemName: "play.fill")
                                        .foregroundStyle(Color.ssBackground)
                                }
                            }
                            .frame(width: 36, height: 36)
                            .background(Color.ssAccent)
                            .clipShape(Circle())
                        }
                        .disabled(loadingRoutineId != nil)
                        .accessibilityLabel("Start \(routine.name)")
                    }
                    .padding(16)
                }
            }
        }
    }

    // MARK: - Recent workouts

    private var recentWorkoutsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Workouts")
                    .font(.headline)
                    .foregroundStyle(Color.ssTextPrimary)
                Spacer()
                Button("See all") { appState.selectedTab = 4 }
                    .font(.subheadline)
                    .foregroundStyle(Color.ssAccent)
            }
            ForEach(recentSessions) { session in
                CardView {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(session.name)
                                .font(.body.weight(.medium))
                                .foregroundStyle(Color.ssTextPrimary)
                            Spacer()
                            Text(session.startedAt, style: .date)
                                .font(.caption)
                                .foregroundStyle(Color.ssTextMuted)
                        }
                        HStack(spacing: 12) {
                            Label(formatDuration(session.duration), systemImage: "clock")
                            Label("\(session.setCount) sets", systemImage: "dumbbell.fill")
                            if session.volumeKg > 0 {
                                let vol = session.volumeKg * appState.weightUnit.kgFactor
                                Label("\(Int(vol.rounded())) \(appState.weightUnit.label)", systemImage: "scalemass.fill")
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(Color.ssTextSecondary)
                    }
                    .padding(16)
                }
            }
        }
    }

    // MARK: - Data loading

    private func refresh() async {
        let todayStr = String.todayFoodDate()

        async let foodL    = foodRepo.fetchLogs(from: todayStr, to: todayStr)
        async let foodT    = foodRepo.fetchTargets()
        async let sessions = workoutRepo.fetchHistory(limit: 20)
        async let bwList   = bwRepo.listBodyWeights()
        async let routL    = routineRepo.listRoutines()

        todayLogs      = (try? await foodL) ?? []
        targets        = try? await foodT

        let allSessions  = (try? await sessions) ?? []
        recentSessions   = Array(allSessions.prefix(3))
        weekWorkoutDays  = Set(allSessions.map {
            Self.localDayFormatter.string(from: $0.startedAt)
        })

        allBodyWeights   = (try? await bwList) ?? []
        latestWeight     = allBodyWeights.last
        hasWeightToday   = allBodyWeights.last?.measuredOn == todayStr

        routines         = Array(((try? await routL) ?? []).prefix(4))
    }

    // MARK: - Routine play

    private func playRoutine(_ summary: RoutineSummary) {
        loadingRoutineId = summary.id
        Task {
            do {
                let routine = try await routineRepo.loadRoutine(id: summary.id)
                appState.startWorkout(from: routine)
            } catch {}
            loadingRoutineId = nil
        }
    }

    // MARK: - Helpers

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good morning,"
        case 12..<17: return "Good afternoon,"
        default:      return "Good evening,"
        }
    }

    private struct WeekDay {
        let label: String
        let dateStr: String
    }

    private var currentWeekDays: [WeekDay] {
        let cal = Calendar.current
        let today = Date()
        let weekday = cal.component(.weekday, from: today) // Sun=1 … Sat=7
        let daysFromMonday = (weekday + 5) % 7             // Mon=0 … Sun=6
        let monday = cal.date(byAdding: .day, value: -daysFromMonday, to: today)!
        let labels = ["M", "T", "W", "T", "F", "S", "S"]
        return (0..<7).map { offset in
            let date = cal.date(byAdding: .day, value: offset, to: monday)!
            return WeekDay(label: labels[offset], dateStr: Self.localDayFormatter.string(from: date))
        }
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let mins = Int(interval / 60)
        guard mins >= 60 else { return "\(mins) min" }
        let h = mins / 60
        let m = mins % 60
        return m == 0 ? "\(h) hr" : "\(h) hr \(m) min"
    }
}
