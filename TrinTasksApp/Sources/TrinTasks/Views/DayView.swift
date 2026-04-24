import SwiftUI

struct DayView: View {
    let date: Date
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var themeManager: ThemeManager

    private var assignments: [Assignment] {
        store.assignments(for: date)
    }

    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 2) {
                Text(dayName)
                    .font(BrutalStyle.font(11, weight: .semibold))
                    .foregroundColor(themeManager.current.primaryText)
                Text(dayNumber)
                    .font(BrutalStyle.font(18, weight: .bold))
                    .foregroundColor(isToday ? themeManager.current.accent : themeManager.current.primaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(themeManager.current.dayHeaderBackground)
            .overlay(
                Rectangle()
                    .frame(height: BrutalStyle.borderWidth)
                    .foregroundColor(themeManager.current.borderColor),
                alignment: .bottom
            )

            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(assignments) { assignment in
                        AssignmentCard(
                            assignment: assignment,
                            subjectColor: store.subjectColor(for: assignment.subject)
                        )
                    }
                    if assignments.isEmpty {
                        Text("—")
                            .font(BrutalStyle.font(12))
                            .foregroundColor(themeManager.current.mutedText)
                            .padding(.top, 16)
                    }
                }
                .padding(6)
            }
            .background(themeManager.current.dayBackground)
        }
        .border(themeManager.current.borderColor, width: BrutalStyle.borderWidth)
    }

    private var dayName: String {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: date).uppercased()
    }

    private var dayNumber: String {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f.string(from: date)
    }
}
