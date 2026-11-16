import SwiftUI

struct RestScreenView: View {
    @Environment(AppState.self) private var appState

    private var workout: WorkoutState { appState.activeWorkout! }
    private var endsAt: Date {
        if case .rest(_, let e) = workout.phase { return e }
        return .now
    }

    var body: some View {
        VStack(spacing: 0) {
            headerRow.padding(.horizontal)
            Divider().background(Color.ssBorder)
            VStack(spacing: 32) {
                Spacer()
                countdownRing
                adjustButtons
                skipButton
                if let next = workout.nextSetInfo {
                    upNext(next)
                }
                Spacer()
            }
            .padding(.horizontal, 24)
        }
        .background(Color.ssBackground)
    }

    private var headerRow: some View {
        HStack {
            Button { appState.isWorkoutPlayerVisible = false } label: {
                Image(systemName: "chevron.down")
                    .font(.title3)
                    .foregroundStyle(Color.ssTextSecondary)
            }
            Spacer()
            Text("Rest")
                .font(.headline)
            Spacer()
            Image(systemName: "chevron.down").opacity(0)
        }
        .padding(.vertical, 12)
    }

    private var countdownRing: some View {
        TimelineView(.animation(minimumInterval: 0.1)) { ctx in
            ringFrame(at: ctx.date)
        }
    }

    @ViewBuilder
    private func ringFrame(at date: Date) -> some View {
        let remaining = max(0, endsAt.timeIntervalSince(date))
        let total: Double = {
            if case .rest(let s, _) = workout.phase { return endsAt.timeIntervalSince(s) }
            return 60
        }()
        let fraction = total > 0 ? remaining / total : 0.0

        ZStack {
            Circle()
                .stroke(Color.ssBorder, lineWidth: 8)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(Color.ssAccent, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.1), value: fraction)
            VStack(spacing: 4) {
                Text(formatRemaining(remaining))
                    .font(.system(size: 56, weight: .bold, design: .monospaced))
                Text("seconds left")
                    .font(.subheadline)
                    .foregroundStyle(Color.ssTextSecondary)
            }
        }
        .frame(width: 220, height: 220)
        .onChange(of: remaining == 0) { _, isZero in
            if isZero {
                AlarmService.shared.play()
                appState.applyWorkoutAction(.endRest)
            }
        }
    }

    private var adjustButtons: some View {
        HStack(spacing: 16) {
            ForEach([-30, -15, 15, 30], id: \.self) { delta in
                Button {
                    appState.applyWorkoutAction(.adjustRest(deltaSeconds: delta))
                } label: {
                    Text(delta > 0 ? "+\(delta)s" : "\(delta)s")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(delta < 0 ? Color.ssTextSecondary : Color.ssAccent)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.ssSurface)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.ssBorder, lineWidth: 1)
                        )
                }
            }
        }
    }

    private var skipButton: some View {
        Button { appState.applyWorkoutAction(.endRest) } label: {
            Text("Skip Rest")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.ssAccent)
        }
    }

    private func upNext(_ info: CurrentSetInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Up next")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.ssTextSecondary)
            HStack {
                Text(info.exerciseName)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(info.prefillReps) reps")
                    .font(.subheadline)
                    .foregroundStyle(Color.ssTextSecondary)
                if let w = info.prefillWeightKg, w > 0 {
                    Text("· \(String(format: "%g", appState.weightUnit.fromKg(w))) \(appState.weightUnit.rawValue)")
                        .font(.subheadline)
                        .foregroundStyle(Color.ssTextSecondary)
                }
            }
        }
        .padding(16)
        .background(Color.ssSurface)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.ssBorder, lineWidth: 1))
    }

    private func formatRemaining(_ t: TimeInterval) -> String {
        let total = Int(t)
        let m = total / 60, s = total % 60
        return m > 0 ? String(format: "%d:%02d", m, s) : "\(s)"
    }
}
