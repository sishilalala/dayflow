import Foundation

// MARK: - Task Source
enum TaskSource: String, Codable, Hashable {
    case reminders   = "reminders"
    case googleTasks = "googleTasks"
    case local       = "local"

    var displayName: String {
        switch self {
        case .reminders:   return "Reminders"
        case .googleTasks: return "Google Tasks"
        case .local:       return "Local"
        }
    }

    var iconName: String {
        switch self {
        case .reminders:   return "bell.fill"
        case .googleTasks: return "checklist"
        case .local:       return "square.and.pencil"
        }
    }
}

// MARK: - Task Category
enum TaskCategory: String, Codable, CaseIterable, Hashable {
    case work     = "work"
    case personal = "personal"
    case health   = "health"
    case family   = "family"
    case other    = "other"

    var displayName: String {
        switch self {
        case .work:     return "Work"
        case .personal: return "Personal"
        case .health:   return "Health"
        case .family:   return "Family"
        case .other:    return "Other"
        }
    }

    var colorHex: String {
        switch self {
        case .work:     return "4A90E2"   // blue
        case .personal: return "5CB85C"   // green
        case .health:   return "F0A500"   // amber
        case .family:   return "9B59B6"   // purple
        case .other:    return "8E8E93"   // gray
        }
    }
}

// MARK: - PlannerTask
struct PlannerTask: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var notes: String?

    // Timeline placement
    var scheduledTime: Date?      // nil = lives in Inbox
    var duration: Int             // minutes, default 30

    // Status
    var isCompleted: Bool

    // Metadata
    var source: TaskSource
    var sourceId: String?         // EKReminder ID or Google Task ID
    var category: TaskCategory
    var priority: Int             // 0=none 1=low 2=medium 3=high
    var dueDate: Date?

    // Timestamps
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        notes: String? = nil,
        scheduledTime: Date? = nil,
        duration: Int = 30,
        isCompleted: Bool = false,
        source: TaskSource = .local,
        sourceId: String? = nil,
        category: TaskCategory = .personal,
        priority: Int = 0,
        dueDate: Date? = nil
    ) {
        self.id            = id
        self.title         = title
        self.notes         = notes
        self.scheduledTime = scheduledTime
        self.duration      = duration
        self.isCompleted   = isCompleted
        self.source        = source
        self.sourceId      = sourceId
        self.category      = category
        self.priority      = priority
        self.dueDate       = dueDate
        self.createdAt     = Date()
        self.updatedAt     = Date()
    }

    // Convenience
    var isScheduled: Bool { scheduledTime != nil }

    var endTime: Date? {
        guard let start = scheduledTime else { return nil }
        return start.addingTimeInterval(TimeInterval(duration * 60))
    }

    var isOverdue: Bool {
        guard !isCompleted, let due = dueDate ?? scheduledTime else { return false }
        return due < Date()
    }
}
