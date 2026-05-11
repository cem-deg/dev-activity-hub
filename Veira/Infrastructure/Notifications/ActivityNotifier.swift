import Foundation
import UserNotifications

enum ActivityNotifier {
    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func notifyPausedButActive() {
        let id = "com.veira.paused-but-active"
        let center = UNUserNotificationCenter.current()
        center.removeDeliveredNotifications(withIdentifiers: [id])

        let content = UNMutableNotificationContent()
        content.title = "Still working?"
        content.body = "Your session is paused. Resume tracking if you're back at work."
        content.sound = .default

        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        center.add(request)
    }

    static func notifyUpdateAvailable(version: String?) {
        let id = "com.veira.update-available"
        let center = UNUserNotificationCenter.current()
        center.removeDeliveredNotifications(withIdentifiers: [id])

        let content = UNMutableNotificationContent()
        content.title = "Veira update available"
        content.body = version.map { "Version \($0) is ready to install." }
            ?? "A new version is ready to install."
        content.sound = .default

        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        center.add(request)
    }

    static func notifyInactivityPause() {
        let id = "com.veira.inactivity-pause"
        let center = UNUserNotificationCenter.current()
        // Clean up any delivered notifications from the legacy identifier.
        center.removeDeliveredNotifications(withIdentifiers: ["com.projectpulse.inactivity-pause"])
        // Remove any delivered copy so the next delivery is treated as new (not suppressed).
        center.removeDeliveredNotifications(withIdentifiers: [id])

        let content = UNMutableNotificationContent()
        content.title = "Session Paused"
        content.body = "Paused due to inactivity. Open Veira to resume."
        content.sound = .default

        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        center.add(request)
    }
}
