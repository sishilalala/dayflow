import Foundation
import Combine

@MainActor
class TaskStore: ObservableObject {

    // MARK: - Published State
    @Published var tasks: [PlannerTask] = []
    @Published var isLoading: Bool = false
    @Published var syncMessage: String? = nil
    @Published var remindersAuthorized: Bool = false

    // MARK: - Services
    let remindersService = RemindersService()
    let googleTasksService = GoogleTasksService()

    // MARK: - Persistence
    private let saveKey = "dayflow_tasks_v1"

    init() {
        loadPersistedTasks()
    }

    // MARK: - Computed Queries

    func tasksForDate(_ date: Date) -> [PlannerTask] {
        let cal = Calendar.current
        return tasks
            .filter { task in
                guard let t = task.scheduledTime else { return false }
                return cal.isDate(t, inSameDayAs: date)
            }
            .filter { !$0.isCompleted }
            .sorted { ($0.scheduledTime ?? .distantPast) < ($1.scheduledTime ?? .distantPast) }
    }

    var inboxTasks: [PlannerTask] {
        tasks
            .filter { !$0.isScheduled && !$0.isCompleted }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var todayCompletedTasks: [PlannerTask] {
        let cal = Calendar.current
        return tasks.filter { $0.isCompleted && cal.isDateInToday($0.updatedAt) }
    }

    // MARK: - CRUD

    func addTask(_ task: PlannerTask) {
        tasks.append(task)
        persist()
    }

    func updateTask(_ task: PlannerTask) {
        guard let i = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[i] = task
        persist()
    }

    func deleteTask(_ task: PlannerTask) {
        tasks.removeAll { $0.id == task.id }
        persist()
    }

    func toggleComplete(_ task: PlannerTask) {
        var t = task
        t.isCompleted = !task.isCompleted
        t.updatedAt = Date()
        updateTask(t)

        // Propagate to source
        if t.isCompleted {
            Task {
                if t.source == .reminders, let sid = t.sourceId {
                    try? remindersService.completeReminder(sourceId: sid)
                } else if t.source == .googleTasks, let sid = t.sourceId {
                    try? await googleTasksService.completeTask(taskId: sid)
                }
            }
        }
    }

    func scheduleTask(_ task: PlannerTask, at time: Date, duration: Int = 30) {
        var t = task
        t.scheduledTime = time
        t.duration = duration
        t.updatedAt = Date()
        updateTask(t)
    }

    func moveTaskToInbox(_ task: PlannerTask) {
        var t = task
        t.scheduledTime = nil
        t.updatedAt = Date()
        updateTask(t)
    }

    // MARK: - Sync

    func syncAll() async {
        isLoading = true
        syncMessage = "Syncing…"
        defer {
            isLoading = false
            syncMessage = nil
        }

        await syncReminders()
        if GoogleTasksService.isAuthorized {
            await syncGoogleTasks()
        }
    }

    func syncReminders() async {
        do {
            let fetched = try await remindersService.fetchReminders()
            mergeExternalTasks(fetched, source: .reminders)
            remindersAuthorized = true
            syncMessage = "Reminders synced ✓"
        } catch {
            syncMessage = "Reminders: \(error.localizedDescription)"
        }
    }

    func syncGoogleTasks() async {
        do {
            let fetched = try await googleTasksService.fetchAllTasks()
            mergeExternalTasks(fetched, source: .googleTasks)
            syncMessage = "Google Tasks synced ✓"
        } catch {
            syncMessage = "Google Tasks: \(error.localizedDescription)"
        }
    }

    // Merge strategy: update existing by sourceId, insert new ones
    private func mergeExternalTasks(_ incoming: [PlannerTask], source: TaskSource) {
        for item in incoming {
            if let i = tasks.firstIndex(where: {
                $0.source == source && $0.sourceId == item.sourceId
            }) {
                // Keep local scheduledTime / category; update title, completion, due
                var existing = tasks[i]
                existing.title       = item.title
                existing.notes       = item.notes ?? existing.notes
                existing.isCompleted = item.isCompleted
                existing.dueDate     = item.dueDate ?? existing.dueDate
                existing.updatedAt   = Date()
                tasks[i] = existing
            } else {
                tasks.append(item)
            }
        }
        persist()
    }

    // MARK: - End-of-Day Summary (text, to be shown in a sheet)
    func endOfDaySummary() -> (incomplete: [PlannerTask], completed: [PlannerTask]) {
        let cal = Calendar.current
        let incomplete = tasks.filter {
            !$0.isCompleted &&
            (($0.scheduledTime.map { cal.isDateInToday($0) }) ?? false)
        }
        let completed = todayCompletedTasks
        return (incomplete, completed)
    }

    // MARK: - Persistence (UserDefaults for now, easy to swap to SwiftData)
    private func persist() {
        guard let data = try? JSONEncoder().encode(tasks) else { return }
        UserDefaults.standard.set(data, forKey: saveKey)
    }

    private func loadPersistedTasks() {
        guard let data = UserDefaults.standard.data(forKey: saveKey),
              let decoded = try? JSONDecoder().decode([PlannerTask].self, from: data) else { return }
        tasks = decoded
    }
}
