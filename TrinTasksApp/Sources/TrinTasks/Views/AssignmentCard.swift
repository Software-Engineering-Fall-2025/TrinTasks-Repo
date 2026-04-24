import SwiftUI

struct AssignmentCard: View {
    let assignment: Assignment
    let subjectColor: Color
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showActionMenu = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Button(action: toggleComplete) {
                Image(systemName: assignment.isCompleted ? "checkmark.square.fill" : "square")
                    .foregroundColor(themeManager.current.accent)
                    .font(.system(size: 16))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(assignment.title)
                    .font(BrutalStyle.font(13, weight: .semibold))
                    .foregroundColor(themeManager.current.primaryText)
                    .strikethrough(assignment.isCompleted)
                    .lineLimit(2)

                if let due = assignment.dueDate {
                    Text(formatDue(due))
                        .font(BrutalStyle.font(11))
                        .foregroundColor(themeManager.current.mutedText)
                }

                if assignment.isPinned {
                    Label("Pinned", systemImage: "pin.fill")
                        .font(BrutalStyle.font(10))
                        .foregroundColor(themeManager.current.accent)
                }
            }

            Spacer()
        }
        .padding(8)
        .brutalCard(fill: subjectColor.opacity(0.85), border: themeManager.current.borderColor)
        .opacity(assignment.isCompleted ? 0.55 : 1)
        .contextMenu { actionMenu }
        .onLongPressGesture { showActionMenu = true }
        .confirmationDialog("", isPresented: $showActionMenu) { actionMenu }
    }

    @ViewBuilder
    private var actionMenu: some View {
        Button(assignment.isPinned ? "Unpin" : "Pin") { togglePin() }
        Button(assignment.isCompleted ? "Mark Incomplete" : "Mark Complete") { toggleComplete() }
        Menu("Set Reminder") {
            Button("15 minutes before") { setReminder(900) }
            Button("1 hour before") { setReminder(3600) }
            Button("1 day before") { setReminder(86400) }
            if assignment.metadata.reminderOffset != nil {
                Button("Remove Reminder") { setReminder(nil) }
            }
        }
    }

    private func toggleComplete() {
        var meta = assignment.metadata
        meta.isCompleted.toggle()
        store.updateMetadata(meta, forUID: assignment.id)
    }

    private func togglePin() {
        var meta = assignment.metadata
        meta.isPinned.toggle()
        store.updateMetadata(meta, forUID: assignment.id)
    }

    private func setReminder(_ offset: TimeInterval?) {
        var meta = assignment.metadata
        meta.reminderOffset = offset
        store.updateMetadata(meta, forUID: assignment.id)
    }

    private func formatDue(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f.string(from: date)
    }
}
