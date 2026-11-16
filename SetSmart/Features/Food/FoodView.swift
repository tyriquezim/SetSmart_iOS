import SwiftUI
import Charts

struct FoodView: View {
    @Environment(AppState.self) private var appState

    @State private var selectedDate = Date()
    @State private var logs: [FoodLog] = []
    @State private var weekLogs: [FoodLog] = []
    @State private var targets: NutritionTargets?
    @State private var addMeal: Meal?
    @State private var showTargets = false
    @State private var chartSelection: String?
    @State private var allWeights: [BodyWeight] = []
    @State private var dayWorkoutTimes: [(startedAt: Date, finishedAt: Date?)] = []
    @State private var showFullExplanation = false

    private let repo        = FoodRepository()
    private let bwRepo      = BodyWeightRepository()
    private let workoutRepo = WorkoutRepository()

    private var selectedDateStr: String { String.foodDateFormatter.string(from: selectedDate) }
    private var isToday: Bool { Calendar.current.isDateInToday(selectedDate) }

    private var totals: (kj: Double, p: Double, c: Double, f: Double) {
        (
            kj: logs.reduce(0) { $0 + $1.energyKj },
            p:  logs.reduce(0) { $0 + $1.proteinG },
            c:  logs.reduce(0) { $0 + $1.carbsG },
            f:  logs.reduce(0) { $0 + $1.fatG }
        )
    }

    var body: some View {
        NavigationStack {
            List {
                // Day switcher
                Section {
                    dayPicker
                        .listRowBackground(Color.ssBackground)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                }

                // Summary card
                Section {
                    summaryCard
                        .listRowBackground(Color.ssBackground)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                }

                // Energy balance card
                Section {
                    energyBalanceCard
                        .listRowBackground(Color.ssBackground)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 8, trailing: 20))
                }

                // 7-day chart
                Section {
                    weekChart
                        .listRowBackground(Color.ssBackground)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 8, trailing: 20))
                }

                // Meals
                ForEach(Meal.allCases) { meal in
                    let entries = logs.filter { $0.meal == meal }
                    Section {
                        if entries.isEmpty {
                            Text("Nothing logged yet")
                                .font(.subheadline)
                                .foregroundStyle(Color.ssTextMuted)
                                .listRowBackground(Color.ssSurface)
                        } else {
                            ForEach(entries) { log in logRow(log) }
                                .onDelete { deleteEntries(entries, $0) }
                        }
                    } header: {
                        mealHeader(meal, entries: entries)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.ssBackground.ignoresSafeArea())
            .navigationTitle("Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showTargets = true } label: {
                        Image(systemName: "target")
                            .foregroundStyle(Color.ssTextSecondary)
                    }
                }
            }
            .task { await refresh(loadTargets: true) }
            .onChange(of: selectedDateStr) { _, _ in Task { await refresh(loadTargets: false) } }
            .sheet(item: $addMeal) { meal in
                AddFoodView(meal: meal, eatenOn: selectedDateStr) { log in
                    logs.append(log)
                    weekLogs.append(log)
                }
                .environment(appState)
            }
            .sheet(isPresented: $showTargets) {
                NutritionTargetsView(initialTargets: targets) { t in targets = t }
                    .environment(appState)
            }
            .sheet(isPresented: $showFullExplanation) {
                FullExplanationSheet(energyUnit: appState.energyUnit)
            }
        }
    }

    // MARK: - Energy balance card

    private var dayEnergyResult: DayEnergyResult? {
        guard let profile = appState.profile else { return nil }
        return estimateDayEnergy(day: selectedDateStr, workouts: dayWorkoutTimes, weights: allWeights, profile: profile)
    }

    private var dayBodyStats: BodyStats? {
        guard let profile = appState.profile else { return nil }
        return bodyStatsOn(day: selectedDateStr, weights: allWeights, profile: profile)
    }

    @ViewBuilder
    private var energyBalanceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ENERGY BALANCE")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.ssTextMuted)
                        .textCase(.uppercase)
                    Text("Burn figures are estimates, not measurements")
                        .font(.caption2)
                        .foregroundStyle(Color.ssTextMuted)
                }
                Spacer()
                Button {
                    showFullExplanation = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "info.circle")
                        Text("How it's worked out")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.ssAccent)
                }
                .buttonStyle(.plain)
            }

            Divider().background(Color.ssBorder)

            if let result = dayEnergyResult {
                switch result {
                case .missing(let missing):
                    energyMissingView(missing)
                case .result(let c):
                    energyResultView(c)
                }
            } else {
                Text("Add your profile details to see energy balance.")
                    .font(.caption)
                    .foregroundStyle(Color.ssTextMuted)
            }
        }
        .padding(16)
        .background(Color.ssSurface)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.ssBorder, lineWidth: 1))
    }

    @ViewBuilder
    private func energyMissingView(_ missing: [MissingDetail]) -> some View {
        let phrases = missing.map { $0.phrase }
        let list: String = {
            if phrases.count == 1 { return phrases[0] }
            if phrases.count == 2 { return "\(phrases[0]) and \(phrases[1])" }
            return phrases.dropLast().joined(separator: ", ") + " and " + phrases.last!
        }()
        Text("To estimate how much energy you burn, \(list).")
            .font(.subheadline)
            .foregroundStyle(Color.ssTextSecondary)
            .fixedSize(horizontal: false, vertical: true)
        HStack(spacing: 16) {
            if missing.contains(.height) || missing.contains(.birthYear) {
                NavigationLink(destination: SettingsView()) {
                    Text("Add body details →")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.ssAccent)
                }
            }
            if missing.contains(.weight) {
                Button { appState.selectedTab = 3 } label: {
                    Text("Log your weight →")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.ssAccent)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func energyResultView(_ c: DayEnergyComponents) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Eaten vs Burned
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Eaten").font(.caption).foregroundStyle(Color.ssTextMuted)
                    Text(formatEnergy(totals.kj, unit: appState.energyUnit))
                        .font(.title3.weight(.bold)).monospacedDigit()
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("Burned (est.)")
                            .font(.caption)
                            .foregroundStyle(Color.ssTextMuted)
                        InfoButton(content: .totalBurn(c), unit: appState.energyUnit)
                    }
                    Text(formatEnergyEstimate(c.totalKcal, unit: appState.energyUnit))
                        .font(.title3.weight(.bold)).monospacedDigit()
                    Text("± \(formatEnergyEstimate(c.totalKcal * 0.1, unit: appState.energyUnit).replacingOccurrences(of: "≈ ", with: "")) or more")
                        .font(.caption2)
                        .foregroundStyle(Color.ssTextMuted)
                }
            }

            Divider().background(Color.ssBorder)

            // Breakdown rows
            let stats = dayBodyStats ?? BodyStats(
                weightKg: 0, bodyFatPct: nil, heightCm: appState.profile?.heightCm,
                age: nil, sex: appState.profile?.sex, dailyActivity: appState.profile?.dailyActivity,
                workoutEffort: appState.profile?.workoutEffort ?? .moderate
            )
            energyBreakdownRow(
                label: "Resting (BMR)",
                kcal: c.restingKcal,
                info: .resting(c.restingResult, stats: stats)
            )
            energyBreakdownRow(
                label: "Everyday activity\(c.activityAssumed ? " (assumed)" : "")",
                kcal: c.everydayKcal,
                info: .everydayActivity(restingKcal: c.restingKcal, pal: c.pal, activity: c.activityAssumed ? nil : appState.profile?.dailyActivity, assumed: c.activityAssumed)
            )
            energyBreakdownRow(
                label: "Workouts",
                kcal: c.workoutKcal,
                info: .workoutsDay(
                    workoutKcal: c.workoutKcal,
                    met: stats.workoutEffort.met,
                    effort: stats.workoutEffort,
                    weightKg: stats.weightKg,
                    restingKcalPerMin: c.restingKcal / 1440
                )
            )

            Divider().background(Color.ssBorder)

            // Verdict
            Text(verdictText(c))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.ssTextPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if isToday {
                Text("The burn is for the whole day, so it assumes the rest of today goes as usual.")
                    .font(.caption)
                    .foregroundStyle(Color.ssTextMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func energyBreakdownRow(label: String, kcal: Double, info: EnergySheetContent) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Color.ssTextSecondary)
            Spacer()
            Text(formatEnergyEstimate(kcal, unit: appState.energyUnit))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(Color.ssTextPrimary)
            InfoButton(content: info, unit: appState.energyUnit)
        }
    }

    private func verdictText(_ c: DayEnergyComponents) -> String {
        let eatenKcal = totals.kj / 4.184
        let diff      = eatenKcal - c.totalKcal
        let margin    = 0.10 * c.totalKcal
        if abs(diff) <= 0.5 * margin {
            return "About even with your estimated burn"
        } else if diff < 0 {
            return "About \(formatEnergyEstimate(-diff, unit: appState.energyUnit)) less than your estimated burn"
        } else {
            return "About \(formatEnergyEstimate(diff, unit: appState.energyUnit)) more than your estimated burn"
        }
    }

    // MARK: - Day picker

    private var dayPicker: some View {
        HStack {
            Button {
                selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .foregroundStyle(Color.ssTextSecondary)
                    .frame(width: 44, height: 44)
            }

            Spacer()

            VStack(spacing: 1) {
                Text(dayTitle)
                    .font(.headline)
                    .foregroundStyle(Color.ssTextPrimary)
                Text(daySubtitle)
                    .font(.caption)
                    .foregroundStyle(Color.ssTextMuted)
            }
            .onTapGesture { selectedDate = Date() }

            Spacer()

            Button {
                selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .foregroundStyle(isToday ? Color.ssBorder : Color.ssTextSecondary)
                    .frame(width: 44, height: 44)
            }
            .disabled(isToday)
        }
        .padding(.horizontal, 12)
    }

    private var dayTitle: String {
        if Calendar.current.isDateInToday(selectedDate) { return "Today" }
        if Calendar.current.isDateInYesterday(selectedDate) { return "Yesterday" }
        let f = DateFormatter(); f.dateFormat = "EEEE"; return f.string(from: selectedDate)
    }

    private var daySubtitle: String {
        let f = DateFormatter(); f.dateFormat = "d MMM yyyy"; return f.string(from: selectedDate)
    }

    // MARK: - Summary card

    private var summaryCard: some View {
        VStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(formatEnergy(totals.kj, unit: appState.energyUnit))
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(Color.ssTextPrimary)
                    .contentTransition(.numericText())
                Text(appState.energyUnit.label)
                    .font(.headline)
                    .foregroundStyle(Color.ssTextSecondary)
                Spacer()
                if let target = targets?.energyKj, target > 0 {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("/ \(formatEnergy(target, unit: appState.energyUnit))")
                            .font(.subheadline)
                            .foregroundStyle(Color.ssTextSecondary)
                        Text("target").font(.caption).foregroundStyle(Color.ssTextMuted)
                    }
                } else {
                    Button { showTargets = true } label: {
                        Text("Set target").font(.caption).foregroundStyle(Color.ssAccent)
                    }
                }
            }

            if let target = targets?.energyKj, target > 0 {
                EnergyMeter(fraction: totals.kj / target)
            }

            HStack(spacing: 0) {
                macroColumn("Protein", grams: totals.p, target: targets?.proteinG)
                Divider().frame(height: 36)
                macroColumn("Carbs",   grams: totals.c, target: targets?.carbsG)
                Divider().frame(height: 36)
                macroColumn("Fat",     grams: totals.f, target: targets?.fatG)
            }
        }
        .padding(16)
        .background(Color.ssSurface)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.ssBorder, lineWidth: 1))
    }

    private func macroColumn(_ label: String, grams: Double, target: Double?) -> some View {
        VStack(spacing: 4) {
            Text("\(formatMacro(grams)) g")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.ssTextPrimary)
            Text(label).font(.caption).foregroundStyle(Color.ssTextMuted)
            if let t = target, t > 0 {
                Text("/ \(formatMacro(t)) g").font(.caption2).foregroundStyle(Color.ssTextMuted)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Week chart

    private struct DayBar: Identifiable {
        var id: String { date }
        var date: String
        var energyKj: Double
        var label: String
    }

    private var weekData: [DayBar] {
        let f = DateFormatter(); f.dateFormat = "EEE"
        return (0..<7).map { offset -> DayBar in
            let d = Calendar.current.date(byAdding: .day, value: offset - 6, to: Date()) ?? Date()
            let dateStr = String.foodDateFormatter.string(from: d)
            let energy = weekLogs.filter { $0.eatenOn == dateStr }.reduce(0) { $0 + $1.energyKj }
            return DayBar(date: dateStr, energyKj: energy, label: f.string(from: d))
        }
    }

    private var weekChart: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Last 7 days")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.ssTextMuted)

            Chart {
                ForEach(weekData) { bar in
                    BarMark(
                        x: .value("Day", bar.label),
                        y: .value(appState.energyUnit.label, appState.energyUnit.fromKj(bar.energyKj))
                    )
                    .foregroundStyle(bar.date == selectedDateStr ? Color.ssAccent : Color.ssChartSeries)
                    .cornerRadius(4)
                }
                if let target = targets?.energyKj, target > 0 {
                    RuleMark(y: .value("Target", appState.energyUnit.fromKj(target)))
                        .lineStyle(StrokeStyle(dash: [4, 4]))
                        .foregroundStyle(Color.ssTextMuted)
                        .annotation(position: .top, alignment: .trailing) {
                            Text("Target").font(.caption2).foregroundStyle(Color.ssTextMuted)
                        }
                }
                if let sel = chartSelection, let bar = weekData.first(where: { $0.label == sel }),
                   bar.energyKj > 0 {
                    RuleMark(x: .value("Day", bar.label))
                        .foregroundStyle(Color.ssBorder)
                        .annotation {
                            Text("\(Int(appState.energyUnit.fromKj(bar.energyKj).rounded())) \(appState.energyUnit.label)")
                                .font(.caption.weight(.semibold))
                                .padding(4)
                                .background(Color.ssSurfaceRaised)
                                .cornerRadius(6)
                        }
                }
            }
            .chartXSelection(value: $chartSelection)
            .chartYAxis { AxisMarks(position: .leading) { AxisValueLabel() } }
            .frame(height: 100)
        }
    }

    // MARK: - Meal header

    private func mealHeader(_ meal: Meal, entries: [FoodLog]) -> some View {
        HStack {
            Label(meal.displayName, systemImage: meal.systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.ssTextPrimary)
                .textCase(nil)
            Spacer()
            if !entries.isEmpty {
                Text("\(Int(appState.energyUnit.fromKj(entries.reduce(0) { $0 + $1.energyKj }).rounded())) \(appState.energyUnit.label)")
                    .font(.caption)
                    .foregroundStyle(Color.ssTextMuted)
                    .textCase(nil)
            }
            Button { addMeal = meal } label: {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(Color.ssAccent)
            }
            .padding(.leading, 4)
        }
    }

    // MARK: - Log row

    private func logRow(_ log: FoodLog) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(log.name)
                    .font(.subheadline)
                    .foregroundStyle(Color.ssTextPrimary)
                Group {
                    if let desc = amountDescription(amount: log.amount, unit: log.amountUnit, servingSize: nil) {
                        Text(desc)
                    } else if let brand = log.brand {
                        Text(brand)
                    }
                }
                .font(.caption)
                .foregroundStyle(Color.ssTextMuted)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text("\(Int(appState.energyUnit.fromKj(log.energyKj).rounded())) \(appState.energyUnit.label)")
                    .font(.caption)
                    .foregroundStyle(Color.ssTextSecondary)
                Text("P \(formatMacro(log.proteinG))  C \(formatMacro(log.carbsG))  F \(formatMacro(log.fatG))")
                    .font(.caption2)
                    .foregroundStyle(Color.ssTextMuted)
            }
        }
        .padding(.vertical, 2)
        .listRowBackground(Color.ssSurface)
    }

    // MARK: - Data

    private func refresh(loadTargets: Bool) async {
        let today = String.todayFoodDate()
        let weekStart = String.foodDate(daysFromToday: -6)
        do {
            allWeights = try await bwRepo.listBodyWeights()
            let slots = try await workoutRepo.fetchWorkoutTimes(localDay: selectedDateStr)
            dayWorkoutTimes = slots.map { ($0.startedAt, $0.finishedAt) }
            weekLogs = try await repo.fetchLogs(from: weekStart, to: today)
            if loadTargets { targets = try await repo.fetchTargets() }
            if selectedDateStr >= weekStart && selectedDateStr <= today {
                logs = weekLogs.filter { $0.eatenOn == selectedDateStr }
            } else {
                logs = try await repo.fetchLogs(from: selectedDateStr, to: selectedDateStr)
            }
        } catch {}
    }

    private func deleteEntries(_ entries: [FoodLog], _ idxSet: IndexSet) {
        let toDelete = idxSet.map { entries[$0] }
        for log in toDelete {
            logs.removeAll { $0.id == log.id }
            weekLogs.removeAll { $0.id == log.id }
            Task { try? await repo.deleteLog(id: log.id) }
        }
    }
}

// MARK: - Energy meter

private struct EnergyMeter: View {
    var fraction: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().foregroundStyle(Color.ssMeterTrack)
                Capsule()
                    .foregroundStyle(fraction > 1 ? Color.ssWarning : Color.ssChartSeries)
                    .frame(width: proxy.size.width * min(fraction, 1))
                    .animation(.easeOut(duration: 0.3), value: fraction)
            }
        }
        .frame(height: 6)
    }
}
