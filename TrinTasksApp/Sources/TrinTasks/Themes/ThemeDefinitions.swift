import SwiftUI

extension Theme {
    static let fern = Theme(
        name: "fern", displayName: "Fern",
        accent: Color(hex: "#2f855a"), accentContrast: .white,
        weekBackground: Color(hex: "#c6f6d5"),
        dayHeaderBackground: Color(hex: "#9ae6b4"),
        dayBackground: Color(hex: "#68d391"),
        isDark: false,
        pageBackground: Color(hex: "#f5f3ee"),
        surfaceBackground: .white,
        primaryText: .black,
        mutedText: Color(hex: "#555555"),
        borderColor: .black
    )

    static let ocean = Theme(
        name: "ocean", displayName: "Ocean",
        accent: Color(hex: "#0ea5e9"), accentContrast: .white,
        weekBackground: Color(hex: "#bae6fd"),
        dayHeaderBackground: Color(hex: "#7dd3fc"),
        dayBackground: Color(hex: "#38bdf8"),
        isDark: false,
        pageBackground: Color(hex: "#f5f3ee"),
        surfaceBackground: .white,
        primaryText: .black,
        mutedText: Color(hex: "#555555"),
        borderColor: .black
    )

    static let sunset = Theme(
        name: "sunset", displayName: "Sunset",
        accent: Color(hex: "#f97316"), accentContrast: .white,
        weekBackground: Color(hex: "#fed7aa"),
        dayHeaderBackground: Color(hex: "#fdba74"),
        dayBackground: Color(hex: "#fb923c"),
        isDark: false,
        pageBackground: Color(hex: "#f5f3ee"),
        surfaceBackground: .white,
        primaryText: .black,
        mutedText: Color(hex: "#555555"),
        borderColor: .black
    )

    static let slate = Theme(
        name: "slate", displayName: "Slate",
        accent: Color(hex: "#64748b"), accentContrast: .white,
        weekBackground: Color(hex: "#e2e8f0"),
        dayHeaderBackground: Color(hex: "#cbd5e1"),
        dayBackground: Color(hex: "#94a3b8"),
        isDark: false,
        pageBackground: Color(hex: "#f5f3ee"),
        surfaceBackground: .white,
        primaryText: .black,
        mutedText: Color(hex: "#555555"),
        borderColor: .black
    )

    static let orchid = Theme(
        name: "orchid", displayName: "Orchid",
        accent: Color(hex: "#a855f7"), accentContrast: .white,
        weekBackground: Color(hex: "#e9d5ff"),
        dayHeaderBackground: Color(hex: "#d8b4fe"),
        dayBackground: Color(hex: "#c084fc"),
        isDark: false,
        pageBackground: Color(hex: "#f5f3ee"),
        surfaceBackground: .white,
        primaryText: .black,
        mutedText: Color(hex: "#555555"),
        borderColor: .black
    )

    static let midnight = Theme(
        name: "midnight", displayName: "Midnight",
        accent: Color(hex: "#60a5fa"), accentContrast: Color(hex: "#1a1f2e"),
        weekBackground: Color(hex: "#334155"),
        dayHeaderBackground: Color(hex: "#334155"),
        dayBackground: Color(hex: "#334155"),
        isDark: true,
        pageBackground: Color(hex: "#1a1f2e"),
        surfaceBackground: Color(hex: "#252b3d"),
        primaryText: Color(hex: "#e5ecf5"),
        mutedText: Color(hex: "#94a3b8"),
        borderColor: Color(hex: "#cbd5e1")
    )

    static let all: [Theme] = [fern, ocean, sunset, slate, orchid, midnight]

    static func named(_ name: String) -> Theme {
        all.first { $0.name == name } ?? .slate
    }
}
