import Foundation

/// Device-only settings stored in UserDefaults (not synced to Supabase).
final class WorkoutSettings {
    static let shared = WorkoutSettings()
    private init() {}

    private let defaults = UserDefaults.standard

    var alarmSoundEnabled: Bool {
        get { defaults.object(forKey: "alarmSound")    == nil ? true : defaults.bool(forKey: "alarmSound") }
        set { defaults.set(newValue, forKey: "alarmSound") }
    }

    var hapticsEnabled: Bool {
        get { defaults.object(forKey: "haptics")       == nil ? true : defaults.bool(forKey: "haptics") }
        set { defaults.set(newValue, forKey: "haptics") }
    }

    var countdownBeepsEnabled: Bool {
        get { defaults.object(forKey: "countdownBeeps") == nil ? true : defaults.bool(forKey: "countdownBeeps") }
        set { defaults.set(newValue, forKey: "countdownBeeps") }
    }

    func reset() {
        defaults.removeObject(forKey: "alarmSound")
        defaults.removeObject(forKey: "haptics")
        defaults.removeObject(forKey: "countdownBeeps")
    }
}
