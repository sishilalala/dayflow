import SwiftUI

struct InboxView: View {

    @EnvironmentObject var store: TaskStore
    @State private var showAddTask = false

    var body: some View {
        NavigationView {
            Group {
                if store.inboxTasks.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(store.inboxTasks) { task in
                            InboxTaskRow(task: task)
                        }
                        .onDelete { idx in
                            idx.forEach { store.deleteTask(store.inboxTasks[$0]) }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Inbox")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAddTask = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddTask) {
                AddTaskView().environmentObject(store)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 52))
                .foregroundStyle(.quaternary)
            Text("Inbox is empty")
                .font(.title3.weight(.semibold))
            Text("Tasks without a scheduled time live here.\nTap + to add one.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - InboxTaskRow
struct InboxTaskRow: View {

    @EnvironmentObject var store: TaskStore
    let task: PlannerTask
    @State private var showSchedule = false

    private var accent: Color { categoryColor(task.category) }

    var body: some View {
        HStack(spacing: 12) {
            // Check button
            Button { store.toggleComplete(task) } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(task.isCompleted ? accent : Color(.tertiaryLabel))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.system(size: 15))
                    .strikethrough(task.isCompleted)
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)

                HStack(spacing: 8) {
                    // Category chip
                    Label(task.category.displayName, systemImage: "")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(accent)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(accent.opacity(0.12), in: Capsule())

                    // Source
                    if task.source != .local {
                        Image(systemName: task.source.iconName)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        Text(task.source.displayName)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }

                    // Due date
                    if let due = task.dueDate {
                        Image(systemName: "calendar")
                            .font(.system(size: 10))
                            .foregroundStyle(due < Date() ? .red : .secondary)
                        Text(due, format: .dateTime.month(.abbreviated).day())
                            .font(.system(size: 11))
                            .foregroundStyle(due < Date() ? .red : .secondary)
                    }
                }
            }

            Spacer()

            // Schedule to today shortcut
            Button { showSchedule = true } label: {
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 16))
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showSchedule) {
            ScheduleTaskSheet(task: task)
                .environmentObject(store)
        }
    }
}

// MARK: - Quick schedule sheet
struct ScheduleTaskSheet: View {

    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var store: TaskStore
    let task: PlannerTask

    @State private var time     = Date()
    @State private var duration = 30

    var body: some View {
        NavigationView {
            Form {
                Section("Schedule on timeline") {
                    DatePicker("Time", selection: $time, displayedComponents: [.date, .hourAndMinute])
                    Stepper("Duration: \(duration) min", value: $duration, in: 15...480, step: 15)
                }
            }
            .navigationTitle("Add to Timeline")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading)  { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Schedule") {
                        store.scheduleTask(task, at: time, duration: duration)
                        dismiss()
                    }.bold()
                }
            }
        }
    }
}
