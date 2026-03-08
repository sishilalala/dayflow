import SwiftUI

// End-of-Day summary sheet — triggered by the moon icon in TimelineView header
struct EndOfDayView: View {

    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var store: TaskStore

    var summary: (incomplete: [PlannerTask], completed: [PlannerTask]) {
        store.endOfDaySummary()
    }

    var body: some View {
        NavigationView {
            List {
                // Completed today
                if !summary.completed.isEmpty {
                    Section {
                        ForEach(summary.completed) { task in
                            Label {
                                Text(task.title)
                                    .strikethrough()
                                    .foregroundStyle(.secondary)
                            } icon: {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                    } header: {
                        Label("Completed today (\(summary.completed.count))", systemImage: "star.fill")
                            .foregroundStyle(.green)
                    }
                }

                // Incomplete (needs rescheduling)
                if !summary.incomplete.isEmpty {
                    Section {
                        ForEach(summary.incomplete) { task in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Image(systemName: "circle")
                                        .foregroundStyle(.secondary)
                                    Text(task.title)
                                }

                                // Quick reschedule buttons
                                HStack(spacing: 8) {
                                    Text("Move to:")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    RescheduleButton(label: "Tomorrow") {
                                        reschedule(task, daysFromNow: 1)
                                    }
                                    RescheduleButton(label: "In 2 days") {
                                        reschedule(task, daysFromNow: 2)
                                    }
                                    RescheduleButton(label: "Next week") {
                                        reschedule(task, daysFromNow: 7)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    } header: {
                        Label("Not done yet (\(summary.incomplete.count))", systemImage: "clock.badge.exclamationmark")
                            .foregroundStyle(.orange)
                    } footer: {
                        Text("Tap a button to reschedule the task to the same time on a future day.")
                            .font(.caption)
                    }
                }

                // All clear
                if summary.incomplete.isEmpty && summary.completed.isEmpty {
                    Section {
                        VStack(spacing: 10) {
                            Image(systemName: "moon.stars.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(.indigo)
                            Text("Nothing scheduled today")
                                .font(.headline)
                            Text("A clean slate — or a very spontaneous day 😄")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("End of Day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .bold()
                }
            }
        }
    }

    private func reschedule(_ task: PlannerTask, daysFromNow: Int) {
        var newTime = Calendar.current.date(byAdding: .day, value: daysFromNow,
                                            to: task.scheduledTime ?? Date()) ?? Date()
        // Keep the same hour/minute
        store.scheduleTask(task, at: newTime, duration: task.duration)
    }
}

// MARK: - Small reschedule chip button
private struct RescheduleButton: View {
    let label:   String
    let action:  () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.blue)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.blue.opacity(0.1), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}
