import Foundation

struct EventMetadata: Codable {
    var isCompleted: Bool = false
    var isPinned: Bool = false
    var reminderOffset: TimeInterval? = nil  // seconds before dueDate; nil = no reminder
}
