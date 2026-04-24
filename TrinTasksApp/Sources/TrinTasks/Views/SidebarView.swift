import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var isVisible: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("SIDEBAR")
                    .font(BrutalStyle.font(11, weight: .bold))
                    .foregroundColor(themeManager.current.primaryText)
                Spacer()
                Button(action: { isVisible = false }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(themeManager.current.primaryText)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(themeManager.current.dayHeaderBackground)
            .border(themeManager.current.borderColor, width: BrutalStyle.borderWidth)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    section(title: "PINNED", assignments: store.pinnedAssignments)
                    section(title: "MAJOR", assignments: store.majorAssignments)
                }
                .padding(8)
            }
        }
        .frame(width: 220)
        .background(themeManager.current.surfaceBackground)
        .border(themeManager.current.borderColor, width: BrutalStyle.borderWidth)
    }

    @ViewBuilder
    private func section(title: String, assignments: [Assignment]) -> some View {
        if !assignments.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(BrutalStyle.font(10, weight: .bold))
                    .foregroundColor(themeManager.current.mutedText)
                ForEach(assignments) { assignment in
                    AssignmentCard(
                        assignment: assignment,
                        subjectColor: store.subjectColor(for: assignment.subject)
                    )
                }
            }
        }
    }
}
