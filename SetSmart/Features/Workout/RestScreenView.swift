import SwiftUI
import UIKit

struct RestScreenView: View {
    @Environment(AppState.self) private var appState

    @State private var alarmRinging = false
    @State private var ringPulse    = false

    private var workout: WorkoutState? { appState.activeWorkout }
    private var endsAt: Date {
        guard let w = workout, case .rest(_, let e) = w.phase else { return .now }
        return e
    }

    var body: some View {
        VStack(spacing: 0) {
            headerRow.padding(.horizontal)
            Divider().background(Color.ssBorder)
            VStack(spacing: 32) {
                Spacer()
                countdownRing
                if !alarmRinging { adjustButtons }
                actionButton
                if let next = workout?.nextSetInfo { upNext(next) }
                Spacer()
            }
            .padding(.horizontal, 24)
        }
        .background(Color.ssBackground)
        .onChange(of: alarmRinging) { _, ringing in
            if ringing {
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    ringPulse = true
                }
            } else {
                withAnimation(.spring) { ringPulse = false }
            }
        }
        .onAppear {
            // Restart alarm if the view reappears after rest already ended (e.g. after minimising)
            if endsAt.timeIntervalSinceNow <= 0 && !alarmRinging {
                alarmRinging = true
                AlarmService.shared.playLooping()
            }
        }
        .onDisappear {
            AlarmService.shared.stop()
            alarmRinging = false
            ringPulse    = false
        }
        // When the app backgrounds, pre-schedule the alarm so it fires even from another app.
        // The audio session stays alive via chained silence buffers (requires Audio background mode).
        .task {
            for await _ in NotificationCenter.default.notifications(named: UIApplication.didEnterBackgroundNotification) {
                guard !alarmRinging else { continue } // alarm already ringing; audio continues as-is
                AlarmService.shared.scheduleLooping(at: endsAt)
            }
        }
        // When foregrounding: either the alarm fired while away (update UI) or rest is still going (cancel pre-schedule).
        .task {
            for await _ in NotificationCenter.default.notifications(named: UIApplication.willEnterForegroundNotification) {
                if endsAt.timeIntervalSinceNow <= 0, !alarmRinging {
                    // Alarm fired in background — audio already looping, just catch up the UI
                    alarmRinging = true
                    HapticsService.restOver()
                } else if endsAt.timeIntervalSinceNow > 0 {
                    // Rest still counting — stop the background pre-schedule
                    AlarmService.shared.stop()
                }
            }
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
            Text(alarmRinging ? "Rest Over" : "Rest")
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
            guard let w = workout, case .rest(let s, _) = w.phase else { return 60 }
            return endsAt.timeIntervalSince(s)
        }()
        let fraction  = total > 0 ? remaining / total : 0.0
        let ringColor = alarmRinging ? Color.ssWarning : Color.ssAccent

        ZStack {
            Circle()
                .stroke(
                    alarmRinging ? Color.ssWarning.opacity(0.25) : Color.ssBorder,
                    lineWidth: 8
                )
            Circle()
                .trim(from: 0, to: alarmRinging ? 1.0 : fraction)
                .stroke(ringColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.1), value: fraction)
            VStack(spacing: 4) {
                Text(alarmRinging ? "0:00" : formatRemaining(remaining))
                    .font(.system(size: 56, weight: .bold, design: .monospaced))
                    .foregroundStyle(alarmRinging ? Color.ssWarning : Color.ssTextPrimary)
                Text(alarmRinging ? "REST OVER" : "seconds left")
                    .font(.subheadline.weight(alarmRinging ? .bold : .regular))
                    .foregroundStyle(alarmRinging ? Color.ssWarning : Color.ssTextSecondary)
                    .tracking(alarmRinging ? 1.5 : 0)
            }
        }
        .frame(width: 220, height: 220)
        .scaleEffect(ringPulse ? 1.04 : 1.0)
        .onChange(of: remaining == 0) { _, isZero in
            if isZero, !alarmRinging {
                // Stay on this screen — user must tap to advance
                alarmRinging = true
                AlarmService.shared.playLooping()
            } else if !isZero, alarmRinging {
                // User extended rest via +button
                alarmRinging = false
                AlarmService.shared.stop()
            }
        }
    }

    // "Skip Rest" while counting, large "Start Next Set" button when alarm is ringing
    @ViewBuilder
    private var actionButton: some View {
        if alarmRinging {
            Button { endRest() } label: {
                Text("Start Next Set")
                    .font(.title3.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
            }
            .buttonStyle(PrimaryButtonStyle())
            .scaleEffect(ringPulse ? 1.04 : 1.0)
        } else {
            Button { endRest() } label: {
                Text("Skip Rest")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.ssAccent)
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

    private func endRest() {
        AlarmService.shared.stop()
        alarmRinging = false
        appState.applyWorkoutAction(.endRest)
    }

    private func formatRemaining(_ t: TimeInterval) -> String {
        let total = Int(t)
        let m = total / 60, s = total % 60
        return m > 0 ? String(format: "%d:%02d", m, s) : "\(s)"
    }
}
