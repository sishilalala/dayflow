import SwiftUI

struct AddTaskView: View {

    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var store: TaskStore

    var presetTime: Date? = nil

    @State private var title       = ""
    @State private var notes       = ""
    @State private var category: TaskCategory = .personal
    @State private var hasTime     = false
    @State private var taskTime    = Date()
    @State private var duration    = 30
    @State private var hasDue      = false
    @State private var dueDate     = Date()
    @State private var destination: TaskSource = .local   // where to also save externally

    var body: some View {
        NavigationView {
            Form {
                // Title + Notes
                Section {
                    TextField("Task title", text: $title)
                        .font(.system(size: 17))
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                        .font(.system(size: 15))
                }

                // Category
                Section("Category") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(TaskCategory.allCases, id: \.self) { cat in
                                CategoryChip(cat: cat, selected: category == cat)
                                    .onTapGesture { category = cat }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                // Timeline placement
                Section("Schedule") {
                    Toggle("Place on timeline", isOn: $hasTime)
                    if hasTime {
                        DatePicker("Date & Time", selection: $taskTime,
                                   displayedComponents: [.date, .hourAndMinute])
                        Stepper("Duration: \(duration) min",
                                value: $duration, in: 15...480, step: 15)
                    }
                    Toggle("Set due date", isOn: $hasDue)
                    if hasDue {
                        DatePicker("Due", selection: $dueDate, displayedComponents: .date)
                    }
                }

                // Where to save
                Section("Also save to") {
                    Picker("Destination", selection: $destination) {
                        Text("DayFlow only").tag(TaskSource.local)
                        Text("Apple Reminders").tag(TaskSource.reminders)
                        Text("Google Tasks").tag(TaskSource.googleTasks)
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") { save(); dismiss() }
                        .bold()
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let t = presetTime { hasTime = true; taskTime = t }
            }
        }
    }

    private func save() {
        let task = PlannerTask(
            title:         title.trimmingCharacters(in: .whitespaces),
            notes:         notes.isEmpty ? nil : notes,
            scheduledTime: hasTime ? taskTime : nil,
            duration:      duration,
            source:        destination == .local ? .local : destination,
            category:      category,
            dueDate:       hasDue ? dueDate : nil
        )
        store.addTask(task)

        // Propagate to external source
        Task {
            if destination == .reminders {
                try? store.remindersService.createReminder(from: task)
            } else if destination == .googleTasks {
                try? await store.googleTasksService.createTask(
                    title:   task.title,
                    notes:   task.notes,
                    dueDate: task.dueDate ?? task.scheduledTime
                )
            }
        }
    }
}

// MARK: - Category chip
private struct CategoryChip: View {
    let cat:      TaskCategory
    let selected: Bool

    var color: Color { categoryColor(cat) }

    var body: some View {
        Text(cat.displayName)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(selected ? .white : color)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(selected ? color : color.opacity(0.12), in: Capsule())
    }
}
