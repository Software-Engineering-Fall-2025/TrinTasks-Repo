import XCTest
@testable import TrinTasks

final class ICalServiceTests: XCTestCase {

    func test_parsesBasicEvent() {
        let ics = """
        BEGIN:VCALENDAR
        BEGIN:VEVENT
        UID:abc-123
        SUMMARY:ENGLISH 11/Fa - C2: Read pages 1-50 due 11:59 PM
        DTSTART:20260425
        END:VEVENT
        END:VCALENDAR
        """
        let events = ICalService.parse(icsString: ics)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].uid, "abc-123")
        XCTAssertTrue(events[0].isAssignment)
        XCTAssertEqual(events[0].subject, "ENGLISH 11/Fa - C2")
    }

    func test_extractsSubjectFromClassPrefix() {
        let ics = """
        BEGIN:VCALENDAR
        BEGIN:VEVENT
        UID:xyz-456
        SUMMARY:ADV. BIOLOGY - B: Lab report due
        DTSTART:20260426
        END:VEVENT
        END:VCALENDAR
        """
        let events = ICalService.parse(icsString: ics)
        XCTAssertEqual(events[0].subject, "ADV. BIOLOGY - B")
        XCTAssertTrue(events[0].isAssignment)
    }

    func test_marksMajorAssignments() {
        let ics = """
        BEGIN:VCALENDAR
        BEGIN:VEVENT
        UID:major-1
        SUMMARY:MATH - C: Unit test Friday
        DTSTART:20260428
        END:VEVENT
        END:VCALENDAR
        """
        let events = ICalService.parse(icsString: ics)
        XCTAssertTrue(events[0].isMajor)
    }

    func test_decodesHtmlEntities() {
        let ics = """
        BEGIN:VCALENDAR
        BEGIN:VEVENT
        UID:entity-1
        SUMMARY:HISTORY - A: Read Ch&#233;kov &amp; respond
        DTSTART:20260425
        END:VEVENT
        END:VCALENDAR
        """
        let events = ICalService.parse(icsString: ics)
        XCTAssertEqual(events[0].title, "HISTORY - A: Read Chékov & respond")
    }

    func test_parsesDateOnlyDTSTART() {
        let ics = """
        BEGIN:VCALENDAR
        BEGIN:VEVENT
        UID:date-1
        SUMMARY:Due assignment
        DTSTART:20260430
        END:VEVENT
        END:VCALENDAR
        """
        let events = ICalService.parse(icsString: ics)
        XCTAssertNotNil(events[0].dueDate)
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month, .day], from: events[0].dueDate!)
        XCTAssertEqual(comps.year, 2026)
        XCTAssertEqual(comps.month, 4)
        XCTAssertEqual(comps.day, 30)
    }
}
