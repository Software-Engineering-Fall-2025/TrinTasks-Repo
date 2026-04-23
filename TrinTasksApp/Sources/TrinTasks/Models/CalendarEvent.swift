import Foundation

struct CalendarEvent: Identifiable, Codable, Equatable {
    let uid: String
    let title: String
    let description: String?
    let location: String?
    let startDate: Date?
    let dueDate: Date?
    let endDate: Date?
    let isAssignment: Bool
    let isMajor: Bool
    let subject: String?
    let rrule: String?
    let trinityFormat: Bool

    var id: String { uid }
}
