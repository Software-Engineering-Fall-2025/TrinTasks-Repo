import Foundation
import Combine
import SwiftUI

@MainActor
final class AppStore: ObservableObject {
    @Published var assignments: [Assignment] = []
    @Published var settings: AppSettings = AppSettings()
    @Published var isLoading: Bool = false
    @Published var lastError: String? = nil

    let storage: StorageService
    let themeManager: ThemeManager
    let notificationService: NotificationService

    private var refreshService: RefreshService?

    init(storage: StorageService = StorageService(), themeManager: ThemeManager = ThemeManager()) {
        self.storage = storage
        self.themeManager = themeManager
        self.notificationService = NotificationService()
        self.settings = storage.loadSettings()
        themeManager.apply(themeName: settings.themeName, glassStyle: settings.isGlassStyle)
    }

    func refresh() async {
        guard !settings.icalURL.isEmpty,
              let url = URL(string: settings.icalURL) else { return }
        isLoading = true
        lastError = nil
        do {
            let events = try await ICalService.fetch(url: url)
            assignments = storage.merge(events: events)
            notificationService.sync(assignments: assignments, settings: settings)
        } catch {
            lastError = error.localizedDescription
        }
        isLoading = false
    }

    func updateMetadata(_ metadata: EventMetadata, forUID uid: String) {
        storage.saveMetadata(metadata, forUID: uid)
        if let idx = assignments.firstIndex(where: { $0.id == uid }) {
            assignments[idx].metadata = metadata
        }
        notificationService.sync(assignments: assignments, settings: settings)
    }

    func saveSettings(_ newSettings: AppSettings) {
        settings = newSettings
        storage.saveSettings(newSettings)
        themeManager.apply(themeName: newSettings.themeName, glassStyle: newSettings.isGlassStyle)
        refreshService?.reschedule(interval: newSettings.refreshInterval)
    }

    func startBackgroundRefresh() {
        refreshService = RefreshService(interval: settings.refreshInterval) { [weak self] in
            Task { await self?.refresh() }
        }
        refreshService?.start()
    }

    // MARK: - Derived

    var pinnedAssignments: [Assignment] {
        assignments.filter { $0.isPinned && !$0.isCompleted }
    }

    var majorAssignments: [Assignment] {
        assignments.filter { $0.isMajor && !$0.isCompleted }
    }

    func assignments(for date: Date) -> [Assignment] {
        let cal = Calendar.current
        return assignments.filter { assignment in
            guard let due = assignment.dueDate else { return false }
            return cal.isDate(due, inSameDayAs: date)
        }.sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }

    func subjectColor(for subject: String?) -> Color {
        guard let subject else { return Color(hex: "#e2e8f0") }
        if let hex = settings.subjectColors[subject] { return Color(hex: hex) }
        let defaults = ["#e63946","#f77f00","#e9c46a","#2a9d8f","#118ab2","#8338ec","#ff006e","#8ac926","#06d6a0","#b56576","#3d405b","#ffb703"]
        let idx = abs(subject.hashValue) % defaults.count
        return Color(hex: defaults[idx])
    }
}
