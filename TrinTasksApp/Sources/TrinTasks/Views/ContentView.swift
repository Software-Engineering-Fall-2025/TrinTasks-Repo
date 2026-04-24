import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var themeManager: ThemeManager
    @State private var weekStart: Date = Calendar.current.startOfWeek(for: Date())
    @State private var showSidebar: Bool = true
    @State private var showSettings: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            TopBarView(
                weekStart: $weekStart,
                showSidebar: $showSidebar,
                showSettings: $showSettings
            )

            HStack(spacing: 0) {
                WeekView(weekStart: weekStart)

                if showSidebar {
                    SidebarView(isVisible: $showSidebar)
                }
            }
        }
        .background(themeManager.current.pageBackground)
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(store)
                .environmentObject(themeManager)
        }
        .frame(minWidth: 700, minHeight: 500)
    }
}
