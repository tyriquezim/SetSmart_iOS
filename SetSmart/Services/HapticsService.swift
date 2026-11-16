import UIKit

struct HapticsService {
    static func loggedSet() {
        guard WorkoutSettings.shared.hapticsEnabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func restOver() {
        guard WorkoutSettings.shared.hapticsEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
