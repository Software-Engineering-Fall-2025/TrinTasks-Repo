import SwiftUI

struct TopBarView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var weekStart: Date
    @Binding var showSidebar: Bool
    @Binding var showSettings: Bool
    @State private var urlInput: String = ""

    var body: some View {
        HStack(spacing: 8) {
            TextField("Paste iCal URL…", text: $urlInput)
                .font(BrutalStyle.font(12))
                .textFieldStyle(.plain)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .brutalCard(fill: themeManager.current.surfaceBackground, border: themeManager.current.borderColor)
                .frame(maxWidth: 280)
                .onSubmit { saveURL() }
                .onAppear { urlInput = store.settings.icalURL }

            headerButton(icon: "arrow.clockwise", action: { Task { await store.refresh() } })

            Button("Today") { goToToday() }
                .font(BrutalStyle.font(12, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .brutalCard(fill: themeManager.current.accent, border: themeManager.current.borderColor)
                .foregroundColor(themeManager.current.accentContrast)
                .buttonStyle(.plain)

            headerButton(icon: "chevron.left", action: { shiftWeek(-1) })
            headerButton(icon: "chevron.right", action: { shiftWeek(1) })

            if store.isLoading {
                ProgressView().scaleEffect(0.7)
            }

            Spacer()

            headerButton(icon: "sidebar.right", action: { showSidebar.toggle() })
            headerButton(icon: "gearshape", action: { showSettings = true })
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(themeManager.current.accent)
        .border(themeManager.current.borderColor, width: BrutalStyle.borderWidth)
    }

    @ViewBuilder
    private func headerButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(themeManager.current.accentContrast)
                .frame(width: 28, height: 28)
                .brutalCard(fill: themeManager.current.accent, border: themeManager.current.accentContrast.opacity(0.4))
        }
        .buttonStyle(.plain)
    }

    private func saveURL() {
        var s = store.settings
        s.icalURL = urlInput
        store.saveSettings(s)
        Task { await store.refresh() }
    }

    private func goToToday() {
        weekStart = Calendar.current.startOfWeek(for: Date())
    }

    private func shiftWeek(_ delta: Int) {
        weekStart = Calendar.current.date(byAdding: .weekOfYear, value: delta, to: weekStart) ?? weekStart
    }
}

extension Calendar {
    func startOfWeek(for date: Date) -> Date {
        let comps = dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return self.date(from: comps) ?? date
    }
}
