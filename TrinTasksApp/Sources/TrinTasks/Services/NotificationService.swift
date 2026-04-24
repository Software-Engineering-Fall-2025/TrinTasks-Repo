import Foundation
import UserNotifications

final class NotificationService {
    // UNUserNotificationCenter requires a valid .app bundle.
    // Guard init so bare SPM executables don't crash — notifications are a no-op in that case.
    private lazy var center: UNUserNotificationCenter? = {
        guard Bundle.main.bundleIdentifier != nil else { return nil }
        return UNUserNotificationCenter.current()
    }()

    func requestAuthorization() {
        center?.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func sync(assignments: [Assignment], settings: AppSettings) {
        guard let center else { return }
        center.getPendingNotificationRequests { [weak self] pending in
            guard let self, let center = self.center else { return }
            let pendingIDs = Set(pending.map { $0.identifier })
            let now = Date()

            for assignment in assignments {
                guard !assignment.isCompleted,
                      let dueDate = assignment.dueDate,
                      let offset = assignment.metadata.reminderOffset else { continue }

                let fireDate = dueDate.addingTimeInterval(-offset)
                guard fireDate > now else { continue }

                let notifID = "reminder.\(assignment.id)"
                if pendingIDs.contains(notifID) { continue }

                let content = UNMutableNotificationContent()
                content.title = assignment.title
                content.body = "Due \(Self.formatDate(dueDate))"
                content.sound = .default

                let interval = fireDate.timeIntervalSinceNow
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(interval, 1), repeats: false)
                let request = UNNotificationRequest(identifier: notifID, content: content, trigger: trigger)
                center.add(request, withCompletionHandler: nil)
            }

            let activeIDs = Set(assignments.compactMap { a -> String? in
                guard !a.isCompleted, a.metadata.reminderOffset != nil else { return nil }
                return "reminder.\(a.id)"
            })
            let toCancel = pendingIDs.filter { $0.hasPrefix("reminder.") && !activeIDs.contains($0) }
            center.removePendingNotificationRequests(withIdentifiers: Array(toCancel))
        }
    }

    private static func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f.string(from: date)
    }
}
