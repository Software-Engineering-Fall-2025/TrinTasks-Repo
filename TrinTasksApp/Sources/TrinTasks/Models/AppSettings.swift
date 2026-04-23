import Foundation

struct AppSettings: Codable {
    var icalURL: String = ""
    var themeName: String = "slate"
    var isGlassStyle: Bool = false
    var refreshInterval: TimeInterval = 1800  // 30 minutes
    var subjectColors: [String: String] = [:]  // subject name → hex string e.g. "#e63946"
}
