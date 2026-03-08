import SwiftUI

// The colored card shown on the timeline for a scheduled task
struct TaskBlockView: View {

    let task: PlannerTask

    private var accentColor: Color { categoryColor(task.category) }

    var body: some View {
        HStack(spacing: 0) {
            // Left color accent bar
            RoundedRectangle(cornerRadius: 2)
                .fill(accentColor)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 2) {
                // Title
                Text(task.title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(2)
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)
                    .strikethrough(task.isCompleted, color: .secondary)

                HStack(spacing: 6) {
                    // Time range
                    if let start = task.scheduledTime, let end = task.endTime {
                        Text("\(start.formatted(.dateTime.hour().minute())) – \(end.formatted(.dateTime.hour().minute()))")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }

                    // Source icon
                    Image(systemName: task.source.iconName)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.leading, 6)
            .padding(.vertical, 5)

            Spacer(minLength: 4)

            // Completion checkmark
            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 14))
                .foregroundStyle(task.isCompleted ? accentColor : Color(.tertiaryLabel))
                .padding(.trailing, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(accentColor.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(accentColor.opacity(0.3), lineWidth: 0.5)
                )
        )
        .opacity(task.isCompleted ? 0.55 : 1)
    }
}

// MARK: - Shared category color helper (used across views)
func categoryColor(_ cat: TaskCategory) -> Color {
    switch cat {
    case .work:     return Color(hex: "4A90E2") // blue
    case .personal: return Color(hex: "5CB85C") // green
    case .health:   return Color(hex: "F0A500") // amber
    case .family:   return Color(hex: "9B59B6") // purple
    case .other:    return Color(hex: "8E8E93") // gray
    }
}

// MARK: - Color from hex string
extension Color {
    init(hex: String) {
        let val = UInt64(hex, radix: 16) ?? 0xAAAAAA
        let r = Double((val >> 16) & 0xFF) / 255
        let g = Double((val >>  8) & 0xFF) / 255
        let b = Double( val        & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
