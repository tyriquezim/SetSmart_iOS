import UserNotifications
import UIKit

/// Manages local notifications for the rest-timer and cardio-goal alarms.
/// Both fire even when the phone is locked — the primary iOS advantage over web.
final class NotificationService: NSObject {
    static let shared = NotificationService()

    private let restEndId     = "com.setsmart.restEnd"
    private let cardioGoalId  = "com.setsmart.cardioGoal"

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func requestPermission() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    // MARK: - Rest end

    func scheduleRestEnd(at fireDate: Date, nextSet: String? = nil) {
        cancel()
        let interval = fireDate.timeIntervalSinceNow
        guard interval > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Rest over — time to lift!"
        content.body  = nextSet ?? "Time to lift!"
        content.sound = .default
        content.interruptionLevel = .active

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: restEndId, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    // MARK: - Cardio goal

    func scheduleCardioGoal(at fireDate: Date, exerciseName: String, goalMin: Int) {
        cancelCardioGoal()
        let interval = fireDate.timeIntervalSinceNow
        guard interval > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Goal reached!"
        content.body  = "\(exerciseName) · \(goalMin) min done"
        content.sound = .default
        content.interruptionLevel = .active

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: cardioGoalId, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    func cancelCardioGoal() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [cardioGoalId])
        UNUserNotificationCenter.current()
            .removeDeliveredNotifications(withIdentifiers: [cardioGoalId])
    }

    // MARK: - Cancel all

    func cancel() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [restEndId, cardioGoalId])
        UNUserNotificationCenter.current()
            .removeDeliveredNotifications(withIdentifiers: [restEndId, cardioGoalId])
    }
}

// Deliver notification as a banner even when app is in foreground.
extension NotificationService: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
