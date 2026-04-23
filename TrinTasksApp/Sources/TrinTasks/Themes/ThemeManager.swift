import SwiftUI
import Combine

final class ThemeManager: ObservableObject {
    @Published var current: Theme = .slate
    @Published var isGlassStyle: Bool = false

    func apply(themeName: String, glassStyle: Bool) {
        current = Theme.named(themeName)
        isGlassStyle = glassStyle
    }

    var pageBackground: Color {
        isGlassStyle ? Color.clear : current.pageBackground
    }

    var effectiveWeekBackground: Color {
        isGlassStyle ? current.weekBackground.opacity(0.5) : current.weekBackground
    }
}
