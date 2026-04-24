import SwiftUI

struct WeekView: View {
    let weekStart: Date
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var themeManager: ThemeManager

    private var days: [Date] {
        (0..<7).compactMap {
            Calendar.current.date(byAdding: .day, value: $0, to: weekStart)
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(days, id: \.self) { day in
                DayView(date: day)
            }
        }
        .background(themeManager.current.weekBackground)
    }
}
