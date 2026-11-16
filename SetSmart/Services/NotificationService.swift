import UserNotifications
import UIKit

/// Manages local notifications for the rest-timer alarm.
/// The notification fires even when the phone is locked — the primary iOS advantage over web.
final class NotificationService: NSObject {
    static let shared = NotificationService()

    private let restEndId = "com.setsmart.restEnd"

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func requestPermission() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    /// Schedule a "Rest over" notification at `fireDate`.
    /// `nextSet` should be e.g. "Bench Press · Set 2 of 3".
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

    func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [restEndId])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [restEndId])
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
