import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss
    @State private var localSettings: AppSettings = AppSettings()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("SETTINGS")
                    .font(BrutalStyle.font(16, weight: .bold))
                    .foregroundColor(themeManager.current.primaryText)
                Spacer()
                Button("Done") {
                    store.saveSettings(localSettings)
                    dismiss()
                }
                .font(BrutalStyle.font(13, weight: .semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .brutalCard(fill: themeManager.current.accent, border: themeManager.current.borderColor)
                .foregroundColor(themeManager.current.accentContrast)
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(themeManager.current.dayHeaderBackground)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    settingsSection(title: "CALENDAR URL") {
                        TextField("https://...", text: $localSettings.icalURL)
                            .font(BrutalStyle.font(12))
                            .textFieldStyle(.roundedBorder)
                    }

                    settingsSection(title: "THEME") {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                            ForEach(Theme.all, id: \.name) { theme in
                                themeButton(theme)
                            }
                        }
                        Toggle("Glass Style", isOn: $localSettings.isGlassStyle)
                            .font(BrutalStyle.font(12))
                            .foregroundColor(themeManager.current.primaryText)
                    }

                    settingsSection(title: "REFRESH INTERVAL") {
                        Picker("", selection: $localSettings.refreshInterval) {
                            Text("15 min").tag(TimeInterval(900))
                            Text("30 min").tag(TimeInterval(1800))
                            Text("1 hour").tag(TimeInterval(3600))
                            Text("Manual only").tag(TimeInterval(0))
                        }
                        .pickerStyle(.segmented)
                        .font(BrutalStyle.font(12))
                    }
                }
                .padding(16)
            }
        }
        .frame(width: 400, height: 500)
        .background(themeManager.current.pageBackground)
        .onAppear { localSettings = store.settings }
    }

    @ViewBuilder
    private func settingsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(BrutalStyle.font(11, weight: .bold))
                .foregroundColor(themeManager.current.mutedText)
            content()
        }
    }

    @ViewBuilder
    private func themeButton(_ theme: Theme) -> some View {
        let isSelected = localSettings.themeName == theme.name
        Button(action: { localSettings.themeName = theme.name }) {
            HStack {
                Circle()
                    .fill(theme.accent)
                    .frame(width: 16, height: 16)
                    .overlay(Circle().stroke(Color.black, lineWidth: 1.5))
                Text(theme.displayName)
                    .font(BrutalStyle.font(12, weight: .semibold))
                    .foregroundColor(themeManager.current.primaryText)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .brutalCard(
                fill: isSelected ? theme.accent.opacity(0.25) : themeManager.current.surfaceBackground,
                border: isSelected ? theme.accent : themeManager.current.borderColor
            )
        }
        .buttonStyle(.plain)
    }
}
