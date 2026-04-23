import Foundation

final class StorageService {
    private let defaults: UserDefaults
    private let settingsKey = "appSettings"
    private let metadataPrefix = "metadata."

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func saveSettings(_ settings: AppSettings) {
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: settingsKey)
        }
    }

    func loadSettings() -> AppSettings {
        guard let data = defaults.data(forKey: settingsKey),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data)
        else { return AppSettings() }
        return settings
    }

    func saveMetadata(_ metadata: EventMetadata, forUID uid: String) {
        if let data = try? JSONEncoder().encode(metadata) {
            defaults.set(data, forKey: metadataPrefix + uid)
        }
    }

    func loadMetadata(forUID uid: String) -> EventMetadata {
        guard let data = defaults.data(forKey: metadataPrefix + uid),
              let metadata = try? JSONDecoder().decode(EventMetadata.self, from: data)
        else { return EventMetadata() }
        return metadata
    }

    func merge(events: [CalendarEvent]) -> [Assignment] {
        return events.map { event in
            Assignment(event: event, metadata: loadMetadata(forUID: event.uid))
        }
    }
}
