import Foundation

final class ICalService {

    // MARK: - Public API

    static func parse(icsString: String) -> [CalendarEvent] {
        let eventBlocks = extractEventBlocks(from: icsString)
        return eventBlocks.compactMap { parseEvent($0) }
    }

    static func fetch(url: URL) async throws -> [CalendarEvent] {
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let icsString = String(data: data, encoding: .utf8) else {
            throw ICalError.invalidEncoding
        }
        return parse(icsString: icsString)
    }

    // MARK: - Parsing

    private static func extractEventBlocks(from ics: String) -> [String] {
        var blocks: [String] = []
        let pattern = "BEGIN:VEVENT([\\s\\S]*?)END:VEVENT"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(ics.startIndex..., in: ics)
        let matches = regex.matches(in: ics, range: range)
        for match in matches {
            if let range = Range(match.range(at: 1), in: ics) {
                blocks.append(String(ics[range]))
            }
        }
        return blocks
    }

    private static func parseEvent(_ block: String) -> CalendarEvent? {
        let uid = extractField("UID", from: block) ?? UUID().uuidString
        var title = extractFoldedField("SUMMARY", from: block) ?? "Untitled Event"
        title = decodeHTMLEntities(unfold(title))
        title = title.replacingOccurrences(of: #"\s+\d+$"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)

        let description = extractFoldedField("DESCRIPTION", from: block).map {
            decodeHTMLEntities(unfold($0))
        }
        let location = extractFoldedField("LOCATION", from: block).map { unfold($0) }

        let subject = extractSubject(from: title)
        let isAssignment = detectAssignment(title: title, subject: subject)
        let isMajor = detectMajor(title: title)

        let startDate = extractDate("DTSTART", from: block)
        let endDate = extractDate("DTEND", from: block)
        let dueDate = extractDate("DUE", from: block) ?? (isAssignment ? startDate : nil)
        let rrule = extractField("RRULE", from: block)

        return CalendarEvent(
            uid: uid,
            title: title,
            description: description,
            location: location,
            startDate: startDate,
            dueDate: dueDate,
            endDate: endDate,
            isAssignment: isAssignment,
            isMajor: isMajor,
            subject: subject,
            rrule: rrule,
            trinityFormat: subject != nil
        )
    }

    // MARK: - Field Extraction

    private static func extractField(_ name: String, from block: String) -> String? {
        let pattern = "\(name):(.+?)(?:\\r?\\n|$)"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: block, range: NSRange(block.startIndex..., in: block)),
              let range = Range(match.range(at: 1), in: block) else { return nil }
        return String(block[range]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func extractFoldedField(_ name: String, from block: String) -> String? {
        let pattern = "\(name):(.+?)(?=\\r?\\n[A-Z\\-]+:|$)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]),
              let match = regex.firstMatch(in: block, range: NSRange(block.startIndex..., in: block)),
              let range = Range(match.range(at: 1), in: block) else { return nil }
        return String(block[range])
    }

    private static func extractDate(_ name: String, from block: String) -> Date? {
        let pattern = "\(name)(?:;[^:]*)?:(.+?)(?:\\r?\\n|$)"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: block, range: NSRange(block.startIndex..., in: block)),
              let range = Range(match.range(at: 1), in: block) else { return nil }
        let raw = String(block[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        return parseICalDate(raw)
    }

    // MARK: - Date Parsing

    static func parseICalDate(_ raw: String) -> Date? {
        let clean = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        // YYYYMMDDTHHMMSSZ
        if clean.count >= 15 && clean.contains("T") {
            formatter.dateFormat = clean.hasSuffix("Z") ? "yyyyMMdd'T'HHmmss'Z'" : "yyyyMMdd'T'HHmmss"
            if clean.hasSuffix("Z") { formatter.timeZone = TimeZone(identifier: "UTC") }
            return formatter.date(from: String(clean.prefix(15)))
        }
        // YYYYMMDD (date only)
        if clean.count == 8 {
            formatter.dateFormat = "yyyyMMdd"
            formatter.timeZone = TimeZone.current
            return formatter.date(from: clean)
        }
        return nil
    }

    // MARK: - Trinity-Specific Logic

    private static func extractSubject(from title: String) -> String? {
        let pattern = #"^((?:ADV\.\s+)?[A-Za-z][A-Za-z0-9\s:\/]+-\s*[A-Za-z0-9]+):"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: title, range: NSRange(title.startIndex..., in: title)),
              let range = Range(match.range(at: 1), in: title) else { return nil }
        return String(title[range]).trimmingCharacters(in: .whitespaces)
    }

    private static func detectAssignment(title: String, subject: String?) -> Bool {
        if subject != nil { return true }
        let keywords = #"\b(due|assignment|homework|test|quiz|exam|project|paper|lab|presentation|read|watch|complete|finish|study)\b"#
        return title.range(of: keywords, options: [.regularExpression, .caseInsensitive]) != nil
    }

    private static func detectMajor(title: String) -> Bool {
        let keywords = #"\b(test|quiz|exam|midterm|final|essay|paper|project|presentation|lab exam|oral exam)\b"#
        return title.range(of: keywords, options: [.regularExpression, .caseInsensitive]) != nil
    }

    // MARK: - Text Processing

    private static func unfold(_ s: String) -> String {
        s.replacingOccurrences(of: "\r\n ", with: "")
         .replacingOccurrences(of: "\r\n\t", with: "")
         .replacingOccurrences(of: "\n ", with: "")
         .replacingOccurrences(of: "\n\t", with: "")
    }

    private static func decodeHTMLEntities(_ s: String) -> String {
        var result = s
        // Numeric decimal entities
        if let regex = try? NSRegularExpression(pattern: "&#(\\d+);") {
            let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))
            for match in matches.reversed() {
                if let codeRange = Range(match.range(at: 1), in: result),
                   let code = UInt32(result[codeRange]),
                   let scalar = Unicode.Scalar(code) {
                    let fullRange = Range(match.range, in: result)!
                    result.replaceSubrange(fullRange, with: String(Character(scalar)))
                }
            }
        }
        // Named entities
        let named: [String: String] = [
            "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"",
            "&#39;": "'", "&nbsp;": " ", "&ndash;": "–", "&mdash;": "—",
            "&ldquo;": "\u{201C}", "&rdquo;": "\u{201D}",
            "&lsquo;": "\u{2018}", "&rsquo;": "\u{2019}"
        ]
        for (entity, char) in named {
            result = result.replacingOccurrences(of: entity, with: char)
        }
        return result
    }
}

enum ICalError: Error {
    case invalidEncoding
    case networkError(Error)
}
