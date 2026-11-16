import SwiftUI
import Charts

struct LiftProgressView: View {
    @State private var summaries: [ExerciseSummary] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let repo = ProgressRepository()

    var body: some View {
        Group {
            if isLoading && summaries.isEmpty {
                ProgressView().tint(Color.ssAccent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if summaries.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .task { await load() }
    }

    private var list: some View {
        List {
            ForEach(summaries) { summary in
                NavigationLink(destination: ExerciseProgressView(summary: summary)) {
                    liftRow(summary)
                }
                .listRowBackground(Color.ssSurface)
                .listRowSeparatorTint(Color.ssBorder)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func liftRow(_ s: ExerciseSummary) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(s.exercise.name)
                    .font(.subheadline.weight(.semibold))
                Text(bestValueLabel(s))
                    .font(.caption)
                    .foregroundStyle(Color.ssTextSecondary)
                    .monospacedDigit()
            }
            Spacer()
            if !s.sparklinePoints.isEmpty {
                sparkline(s.sparklinePoints)
            }
        }
        .padding(.vertical, 4)
    }

    private func bestValueLabel(_ s: ExerciseSummary) -> String {
        if s.isPrimarilyBodyweight {
            return "Best: \(s.maxReps) reps"
        } else if let e = s.bestE1rmKg {
            return "e1RM: \(String(format: "%.1f", e)) kg"
        }
        return ""
    }

    private func sparkline(_ points: [Double]) -> some View {
        let min = points.min() ?? 0
        let max = points.max() ?? 1
        let yDomain = min == max ? (min - 1)...(max + 1) : min...max

        return Chart(points.indices, id: \.self) { i in
            LineMark(
                x: .value("", i),
                y: .value("", points[i])
            )
            .foregroundStyle(Color.ssChartSeries)
            .interpolationMethod(.monotone)
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: yDomain)
        .frame(width: 64, height: 28)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color.ssTextMuted)
            Text("No lifts logged yet")
                .foregroundStyle(Color.ssTextMuted)
            Text("Complete a workout to see your progress here.")
                .font(.caption)
                .foregroundStyle(Color.ssTextMuted)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func load() async {
        isLoading = true
        do { summaries = try await repo.fetchExerciseSummaries() }
        catch { errorMessage = error.localizedDescription }
        isLoading = false
    }
}
