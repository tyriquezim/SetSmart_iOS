import SwiftUI
import Charts

struct ExerciseProgressView: View {
    let summary: ExerciseSummary

    @Environment(AppState.self) private var appState
    @State private var allStats:    [ExerciseSessionStats] = []
    @State private var isLoading    = false
    @State private var metric       = LiftMetric.e1rm
    @State private var range        = ProgressRange.sixMonths
    @State private var selectedDate: Date?

    private let repo = ProgressRepository()
    private var unit: WeightUnit { appState.weightUnit }

    private var availableMetrics: [LiftMetric] {
        summary.isPrimarilyBodyweight
            ? [.reps]
            : LiftMetric.allCases
    }

    private var filtered: [ExerciseSessionStats] {
        guard let days = range.days else { return allStats }
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: .now)!
        return allStats.filter { $0.startedAt >= cutoff }
    }

    private var chartPoints: [(date: Date, value: Double)] {
        filtered.compactMap { s -> (Date, Double)? in
            switch metric {
            case .e1rm:   guard let v = s.bestE1rmKg?.value,  v > 0 else { return nil }; return (s.startedAt, unit.fromKg(v))
            case .weight: guard let v = s.maxWeightKg?.value, v > 0 else { return nil }; return (s.startedAt, unit.fromKg(v))
            case .volume: guard let v = s.volumeKg?.value,    v > 0 else { return nil }; return (s.startedAt, unit.fromKg(v))
            case .reps:   guard s.maxReps > 0 else { return nil };                       return (s.startedAt, Double(s.maxReps))
            }
        }
    }

    private var records: ExerciseRecords { computeRecords(allStats) }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if isLoading {
                    ProgressView().tint(Color.ssAccent).padding(.top, 40)
                } else {
                    recordTiles
                    metricPicker
                    rangePicker
                    chart
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .background(Color.ssBackground.ignoresSafeArea())
        .navigationTitle(summary.exercise.name)
        .navigationBarTitleDisplayMode(.large)
        .task { await load() }
        .onAppear {
            // Default to reps for bodyweight exercises
            if summary.isPrimarilyBodyweight { metric = .reps }
        }
    }

    // MARK: - Record tiles

    private var recordTiles: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Records")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.ssTextSecondary)
            HStack(spacing: 10) {
                if !summary.isPrimarilyBodyweight {
                    recordTile(label: "Best e1RM",
                               value: records.bestE1rm.map { "\(String(format: "%.1f", unit.fromKg($0.value))) \(unit.rawValue)" },
                               date: records.bestE1rm?.date)
                    recordTile(label: "Heaviest",
                               value: records.heaviest.map { "\(String(format: "%.1f", unit.fromKg($0.value))) \(unit.rawValue)" },
                               date: records.heaviest?.date)
                }
                recordTile(label: "Best volume",
                           value: records.bestVolume.map { "\(String(format: "%.1f", unit.fromKg($0.value))) \(unit.rawValue)" },
                           date: records.bestVolume?.date)
                recordTile(label: "Best reps",
                           value: records.bestReps.map { "\($0.value)" },
                           date: records.bestReps?.date)
            }
        }
    }

    private func recordTile(label: String, value: String?, date: Date?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(Color.ssTextSecondary)
            Text(value ?? "—")
                .font(.subheadline.weight(.bold).monospacedDigit())
            if let d = date {
                Text(d, style: .date)
                    .font(.caption2)
                    .foregroundStyle(Color.ssTextMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.ssSurface)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.ssBorder))
    }

    // MARK: - Metric picker

    @ViewBuilder
    private var metricPicker: some View {
        if availableMetrics.count > 1 {
            HStack(spacing: 6) {
                ForEach(availableMetrics, id: \.self) { m in
                    Button(m.rawValue) { metric = m }
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(metric == m ? Color.ssSurfaceRaised : Color.clear)
                        .foregroundStyle(metric == m ? Color.ssTextPrimary : Color.ssTextSecondary)
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(metric == m ? Color.ssBorder : Color.clear))
                }
                Spacer()
            }
        }
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
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(range == r ? Color.ssBorder : Color.clear))
            }
            Spacer()
        }
    }

    // MARK: - Chart

    private var yAxisLabel: String {
        switch metric {
        case .e1rm, .weight, .volume: return unit.rawValue
        case .reps: return "reps"
        }
    }

    private var chart: some View {
        VStack(alignment: .leading, spacing: 4) {
            if chartPoints.isEmpty {
                Text("No data for this range")
                    .font(.subheadline)
                    .foregroundStyle(Color.ssTextMuted)
                    .frame(maxWidth: .infinity, minHeight: 160, alignment: .center)
            } else {
                Chart {
                    ForEach(chartPoints, id: \.date) { p in
                        LineMark(x: .value("Date", p.date), y: .value(metric.rawValue, p.value))
                            .foregroundStyle(Color.ssChartSeries)
                            .interpolationMethod(.monotone)
                        PointMark(x: .value("Date", p.date), y: .value(metric.rawValue, p.value))
                            .foregroundStyle(Color.ssChartSeries)
                            .symbolSize(32)
                    }
                    if let sel = selectedDate, let nearest = closestPoint(to: sel) {
                        RuleMark(x: .value("Selected", nearest.date))
                            .foregroundStyle(Color.ssBorder)
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                            .annotation(position: .top, alignment: .center) {
                                VStack(spacing: 2) {
                                    Text(nearest.date, style: .date)
                                        .font(.caption2)
                                        .foregroundStyle(Color.ssTextMuted)
                                    Text(String(format: "%.1f %@", nearest.value, yAxisLabel))
                                        .font(.caption.weight(.semibold).monospacedDigit())
                                }
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
                .frame(height: 220)
            }
        }
    }

    // MARK: - Helpers

    private func closestPoint(to date: Date) -> (date: Date, value: Double)? {
        chartPoints.min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) })
    }

    private func load() async {
        isLoading = true
        do { allStats = try await repo.fetchExerciseStats(exerciseId: summary.id) } catch {}
        isLoading = false
    }
}
