import XCTest
@testable import TrinTasks

final class StorageServiceTests: XCTestCase {
    var storage: StorageService!

    override func setUp() {
        super.setUp()
        storage = StorageService(defaults: UserDefaults(suiteName: "test-\(UUID().uuidString)")!)
    }

    func test_saveAndLoadSettings() {
        var settings = AppSettings()
        settings.icalURL = "https://example.com/cal.ics"
        settings.themeName = "ocean"
        storage.saveSettings(settings)
        let loaded = storage.loadSettings()
        XCTAssertEqual(loaded.icalURL, "https://example.com/cal.ics")
        XCTAssertEqual(loaded.themeName, "ocean")
    }

    func test_mergePreservesCompletionState() {
        let uid = "test-uid-1"
        var metadata = EventMetadata()
        metadata.isCompleted = true
        storage.saveMetadata(metadata, forUID: uid)

        let event = CalendarEvent(
            uid: uid, title: "Test", description: nil, location: nil,
            startDate: Date(), dueDate: Date(), endDate: nil,
            isAssignment: true, isMajor: false, subject: "MATH",
            rrule: nil, trinityFormat: true
        )
        let merged = storage.merge(events: [event])
        XCTAssertEqual(merged.count, 1)
        XCTAssertTrue(merged[0].isCompleted)
    }

    func test_mergeNewEventHasDefaultMetadata() {
        let event = CalendarEvent(
            uid: "new-uid", title: "New", description: nil, location: nil,
            startDate: Date(), dueDate: Date(), endDate: nil,
            isAssignment: true, isMajor: false, subject: nil,
            rrule: nil, trinityFormat: false
        )
        let merged = storage.merge(events: [event])
        XCTAssertFalse(merged[0].isCompleted)
        XCTAssertFalse(merged[0].isPinned)
    }

    func test_updateMetadata() {
        let uid = "update-uid"
        var metadata = EventMetadata()
        metadata.isPinned = true
        storage.saveMetadata(metadata, forUID: uid)
        let loaded = storage.loadMetadata(forUID: uid)
        XCTAssertTrue(loaded.isPinned)
    }
}
