import SwiftUI
import Charts

struct BodyWeightSection: View {
    @Environment(AppState.self) private var appState

    @State private var allEntries:   [BodyWeight] = []
    @State private var isLoading     = false
    @State private var range         = ProgressRange.threeMonths
    @State private var logWeight     = ""
    @State private var logBodyFat    = ""
    @State private var bodyFatError: String?
    @State private var isSaving      = false
    @State private var saveError:    String?
    @State private var showAllEntries = false
    @State private var selectedDate: Date?

    private let repo = BodyWeightRepository()

    private var unit: WeightUnit { appState.weightUnit }

    private var filtered: [BodyWeight] {
        guard let days = range.days else { return allEntries }
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: .now)!
        return allEntries.filter { $0.date >= cutoff }
    }

    private var points: [(date: Date, value: Double)] {
        filtered.map { ($0.date, unit.fromKg($0.weightKg)) }
    }

    private var avgLine: [(date: Date, avg: Double)] { sevenDayAverage(points) }

    private var latestWeight: Double? { allEntries.last.map { unit.fromKg($0.weightKg) } }
    private var currentAvg: Double?   { avgLine.last?.avg }
    private var change30:   Double?   { changeOver(points, days: 30) }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                logCard
                if isLoading {
                    ProgressView().tint(Color.ssAccent).padding(.top, 40)
                } else if allEntries.isEmpty {
                    emptyState
                } else {
                    headlineRow
                    rangePicker
                    chart
                    allEntriesButton
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .task { await load() }
        .sheet(isPresented: $showAllEntries, onDismiss: { Task { await load() } }) {
            BodyWeightListView(repo: repo)
        }
    }

    // MARK: - Log card

    private var logCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Log today")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.ssTextSecondary)

            // Weight row
            HStack(spacing: 12) {
                TextField("0.0", text: $logWeight)
                    .keyboardType(.decimalPad)
                    .padding(12)
                    .background(Color.ssBackground)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.ssBorder))
                Text(unit.rawValue)
                    .foregroundStyle(Color.ssTextSecondary)
                Button {
                    guard let v = Double(logWeight), v > 0 else { return }
                    if let bfStr = logBodyFat.isEmpty ? nil : logBodyFat,
                       let bfVal = Double(bfStr), (bfVal < 3 || bfVal > 70) {
                        bodyFatError = "Enter a body fat % between 3 and 70."
                        return
                    }
                    bodyFatError = nil; isSaving = true; saveError = nil
                    Task {
                        do {
                            let kg = unit.toKg(v)
                            let bf = logBodyFat.isEmpty ? nil : Double(logBodyFat)
                            try await repo.logBodyWeight(weightKg: kg, bodyFatPct: bf, measuredOn: .now, note: nil)
                            logWeight = ""; logBodyFat = ""
                            await load()
                        } catch { saveError = error.localizedDescription }
                        isSaving = false
                    }
                } label: {
                    if isSaving { ProgressView().tint(.black).frame(width: 60, height: 36) }
                    else { Text("Save").frame(width: 60, height: 36) }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isSaving || Double(logWeight) == nil)
            }

            // Body fat row
            HStack(spacing: 8) {
                TextField("Body fat", text: $logBodyFat)
                    .keyboardType(.decimalPad)
                    .padding(12)
                    .background(Color.ssBackground)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(bodyFatError != nil ? Color.ssDanger : Color.ssBorder))
                Text("%")
                    .foregroundStyle(Color.ssTextSecondary)
                Spacer()
            }

            Text("Body fat % is optional (e.g. from a smart scale). It makes energy estimates reflect your muscle.")
                .font(.caption)
                .foregroundStyle(Color.ssTextMuted)

            if let err = bodyFatError ?? saveError {
                Text(err).font(.caption).foregroundStyle(Color.ssDanger)
            }
        }
        .padding(16)
        .background(Color.ssSurface)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.ssBorder))
    }

    // MARK: - Headline

    private var latestBodyFat: Double? { allEntries.last?.bodyFatPct }

    private var headlineRow: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                headlineStat(
                    value: latestWeight.map { String(format: "%.1f", $0) } ?? "—",
                    label: "Latest (\(unit.rawValue))"
                )
                Divider().frame(height: 36).background(Color.ssBorder)
                headlineStat(
                    value: currentAvg.map { String(format: "%.1f", $0) } ?? "—",
                    label: "7-day avg"
                )
                Divider().frame(height: 36).background(Color.ssBorder)
                headlineChangeStat
            }
            if let bf = latestBodyFat {
                Divider().background(Color.ssBorder)
                Text(String(format: "%.1f%% body fat", bf))
                    .font(.caption)
                    .foregroundStyle(Color.ssTextSecondary)
                    .padding(.vertical, 8)
            }
        }
        .padding(16)
        .background(Color.ssSurface)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.ssBorder))
    }

    private func headlineStat(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3.weight(.bold).monospacedDigit())
            Text(label)
                .font(.caption)
                .foregroundStyle(Color.ssTextSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var headlineChangeStat: some View {
        VStack(spacing: 2) {
            if let c = change30 {
                Text((c >= 0 ? "+" : "") + String(format: "%.1f", c))
                    .font(.title3.weight(.bold).monospacedDigit())
                    .foregroundStyle(c < 0 ? Color.ssAccent : Color.ssTextPrimary)
            } else {
                Text("—").font(.title3.weight(.bold))
            }
            Text("30-day change")
                .font(.caption)
                .foregroundStyle(Color.ssTextSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Range picker

    private var rangePicker: some View {
        HStack(spacing: 6) {
            ForEach(ProgressRange.allCases, id: \.self) { r in
                Button(r.rawValue) { range = r }
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(range == r ? Color.ssSurfaceRaised : Color.clear)
                    .foregroundStyle(range == r ? Color.ssTextPrimary : Color.ssTextSecondary)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(range == r ? Color.ssBorder : Color.clear)
                    )
            }
            Spacer()
        }
    }

    // MARK: - Chart

    private var chart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Chart {
                // Raw dots (grey)
                ForEach(points, id: \.date) { p in
                    PointMark(x: .value("Date", p.date), y: .value("Weight", p.value))
                        .foregroundStyle(Color.ssChartDeemphasis)
                        .symbolSize(28)
                }
                // 7-day average line (lime)
                ForEach(avgLine, id: \.date) { p in
                    LineMark(x: .value("Date", p.date), y: .value("Avg", p.avg))
                        .foregroundStyle(Color.ssChartSeries)
                        .interpolationMethod(.monotone)
                }
                // Tooltip selection rule
                if let sel = selectedDate,
                   let nearest = closestPoint(to: sel) {
                    RuleMark(x: .value("Selected", nearest.date))
                        .foregroundStyle(Color.ssBorder)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                        .annotation(position: .top, alignment: .center) {
                            Text(String(format: "%.1f %@", nearest.value, unit.rawValue))
                                .font(.caption.monospacedDigit())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.ssSurface)
                                .cornerRadius(6)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.ssBorder))
                        }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) {
                    AxisValueLabel().foregroundStyle(Color.ssTextMuted)
                }
            }
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) {
                    AxisGridLine().foregroundStyle(Color.ssBorder)
                    AxisValueLabel().foregroundStyle(Color.ssTextMuted)
                }
            }
            .chartXSelection(value: $selectedDate)
            .frame(height: 200)
        }
    }

    // MARK: - All entries button

    private var allEntriesButton: some View {
        Button { showAllEntries = true } label: {
            HStack {
                Text("Show all entries (\(allEntries.count))")
                    .font(.subheadline)
                    .foregroundStyle(Color.ssAccent)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Color.ssTextMuted)
            }
            .padding(16)
            .background(Color.ssSurface)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.ssBorder))
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "scalemass")
                .font(.system(size: 40))
                .foregroundStyle(Color.ssTextMuted)
            Text("No entries yet")
                .foregroundStyle(Color.ssTextMuted)
            Text("Log your weight above to start tracking.")
                .font(.caption)
                .foregroundStyle(Color.ssTextMuted)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 32)
    }

    // MARK: - Helpers

    private func closestPoint(to date: Date) -> (date: Date, value: Double)? {
        points.min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) })
    }

    private func load() async {
        isLoading = true
        do { allEntries = try await repo.listBodyWeights() } catch {}
        isLoading = false
    }
}

// MARK: - All entries list (sheet)

struct BodyWeightListView: View {
    let repo: BodyWeightRepository
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var entries: [BodyWeight] = []
    @State private var isLoading = false
    @State private var deleteError: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView().tint(Color.ssAccent)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if entries.isEmpty {
                    Text("No entries")
                        .foregroundStyle(Color.ssTextMuted)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    list
                }
            }
            .background(Color.ssBackground.ignoresSafeArea())
            .navigationTitle("All Entries")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.ssAccent)
                }
            }
        }
        .task { await load() }
    }

    private var list: some View {
        List {
            ForEach(entries.reversed()) { entry in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.measuredOn)
                            .font(.subheadline.weight(.semibold))
                        if let note = entry.note, !note.isEmpty {
                            Text(note).font(.caption).foregroundStyle(Color.ssTextSecondary)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "%.1f %@",
                                    appState.weightUnit.fromKg(entry.weightKg),
                                    appState.weightUnit.rawValue))
                        .font(.subheadline.monospacedDigit())
                        Text(entry.bodyFatPct.map { String(format: "%.1f%%", $0) } ?? "—")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(Color.ssTextMuted)
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        Task { await delete(entry) }
                    } label: { Label("Delete", systemImage: "trash") }
                }
                .listRowBackground(Color.ssSurface)
                .listRowSeparatorTint(Color.ssBorder)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func load() async {
        isLoading = true
        do { entries = try await repo.listBodyWeights() } catch {}
        isLoading = false
    }

    private func delete(_ entry: BodyWeight) async {
        do {
            try await repo.deleteBodyWeight(id: entry.id)
            entries.removeAll { $0.id == entry.id }
        } catch { deleteError = error.localizedDescription }
    }
}
