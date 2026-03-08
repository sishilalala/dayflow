import Foundation
import EventKit

class RemindersService {

    // Use a fresh store each fetch to avoid EventKit cache issues
    private var store = EKEventStore()

    // MARK: - Authorization

    var authStatus: EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .reminder)
    }

    func requestAccess() async throws -> Bool {
        if #available(iOS 17.0, *) {
            return try await store.requestFullAccessToReminders()
        } else {
            return try await withCheckedThrowingContinuation { cont in
                store.requestAccess(to: .reminder) { granted, error in
                    if let error { cont.resume(throwing: error) }
                    else         { cont.resume(returning: granted) }
                }
            }
        }
    }

    // MARK: - Fetch

    func fetchReminders() async throws -> [PlannerTask] {
        // Fresh store instance to bypass EventKit's in-memory cache
        store = EKEventStore()

        // Always request access on the new instance (no-op if already granted)
        let granted = try await requestAccess()
        guard granted else {
            throw RemindersError.accessDenied
        }

        let calendars  = store.calendars(for: .reminder)
        let predicate  = store.predicateForReminders(in: calendars)

        return try await withCheckedThrowingContinuation { cont in
            store.fetchReminders(matching: predicate) { reminders in
                guard let reminders else {
                    cont.resume(returning: [])
                    return
                }
                let tasks: [PlannerTask] = reminders
                    .filter { !$0.isCompleted }
                    .map { r in
                        var dueDate: Date? = nil
                        var scheduledTime: Date? = nil

                        if let comps = r.dueDateComponents {
                            let date = Calendar.current.date(from: comps)
                            dueDate = date
                            // If reminder has a specific hour set → place on timeline
                            // If date-only (no hour) → goes to Inbox
                            if comps.hour != nil {
                                scheduledTime = date
                            }
                        }

                        return PlannerTask(
                            title:         r.title ?? "Untitled",
                            notes:         r.notes,
                            scheduledTime: scheduledTime,
                            source:        .reminders,
                            sourceId:      r.calendarItemIdentifier,
                            category:      .personal,
                            dueDate:       dueDate
                        )
                    }
                cont.resume(returning: tasks)
            }
        }
    }

    // MARK: - Write

    /// Create a new EKReminder from a PlannerTask
    func createReminder(from task: PlannerTask) throws {
        let r          = EKReminder(eventStore: store)
        r.title        = task.title
        r.notes        = task.notes
        r.calendar     = store.defaultCalendarForNewReminders()

        if let due = task.dueDate ?? task.scheduledTime {
            r.dueDateComponents = Calendar.current
                .dateComponents([.year, .month, .day, .hour, .minute], from: due)
        }

        try store.save(r, commit: true)
    }

    /// Mark an existing reminder as completed
    func completeReminder(sourceId: String) throws {
        guard let item = store.calendarItem(withIdentifier: sourceId) as? EKReminder else { return }
        item.isCompleted = true
        try store.save(item, commit: true)
    }
}

// MARK: - Errors
enum RemindersError: LocalizedError {
    case accessDenied
    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Reminders access was denied. Please enable it in Settings > Privacy > Reminders."
        }
    }
}
