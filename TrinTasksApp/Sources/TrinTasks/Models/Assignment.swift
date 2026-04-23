import Foundation

struct Assignment: Identifiable {
    let event: CalendarEvent
    var metadata: EventMetadata

    var id: String { event.uid }
    var title: String { event.title }
    var dueDate: Date? { event.dueDate }
    var subject: String? { event.subject }
    var isCompleted: Bool { metadata.isCompleted }
    var isPinned: Bool { metadata.isPinned }
    var isMajor: Bool { event.isMajor }
    var description: String? { event.description }
}
