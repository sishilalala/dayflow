import SwiftUI

struct TimelineView: View {

    @EnvironmentObject var store: TaskStore
    @State private var selectedDate = Date()
    @State private var showAddTask  = false
    @State private var tappedHour: Int? = nil
    @State private var showEOD      = false   // end-of-day summary

    // Layout constants
    let hourH: CGFloat  = 64     // height of one hour row
    let timeW: CGFloat  = 52     // width of the left time label column

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                headerBar
                Divider()
                syncBanner
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        ZStack(alignment: .topLeading) {
                            hourGrid
                            tasksLayer
                            if Calendar.current.isDateInToday(selectedDate) {
                                currentTimeLine
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: hourH * 25)
                        .padding(.bottom, 40)
                    }
                    .onAppear {
                        let h = max(Calendar.current.component(.hour, from: Date()) - 1, 0)
                        withAnimation { proxy.scrollTo(h, anchor: .top) }
                    }
                    .onChange(of: selectedDate) { _ in
                        let h = Calendar.current.isDateInToday(selectedDate)
                            ? max(Calendar.current.component(.hour, from: Date()) - 1, 0)
                            : 8
                        withAnimation { proxy.scrollTo(h, anchor: .top) }
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showAddTask) {
                AddTaskView(presetTime: tappedHour.map { hourAsDate($0) })
                    .environmentObject(store)
            }
            .sheet(isPresented: $showEOD) {
                EndOfDayView().environmentObject(store)
            }
        }
    }

    // MARK: - Header
    private var headerBar: some View {
        HStack(spacing: 0) {
            // Date info
            VStack(alignment: .leading, spacing: 1) {
                Text(selectedDate, format: .dateTime.weekday(.wide))
                    .font(.title3.bold())
                Text(selectedDate, format: .dateTime.month(.abbreviated).day())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 16) {
                // Prev day
                Button { shiftDay(-1) } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                }

                // Today pill
                Button { selectedDate = Date() } label: {
                    Text("Today")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Calendar.current.isDateInToday(selectedDate) ? .blue : .secondary)
                }

                // Next day
                Button { shiftDay(1) } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 15, weight: .semibold))
                }

                // EOD summary (only today)
                if Calendar.current.isDateInToday(selectedDate) {
                    Button { showEOD = true } label: {
                        Image(systemName: "moon.stars")
                            .font(.system(size: 18))
                    }
                }

                // Add
                Button {
                    tappedHour = Calendar.current.component(.hour, from: Date())
                    showAddTask = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.blue)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Sync banner
    @ViewBuilder
    private var syncBanner: some View {
        if let msg = store.syncMessage {
            HStack {
                if store.isLoading { ProgressView().scaleEffect(0.7) }
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity)
            .background(Color(.systemGroupedBackground))
        }
    }

    // MARK: - Hour grid (background)
    private var hourGrid: some View {
        VStack(spacing: 0) {
            ForEach(0..<25, id: \.self) { h in
                HStack(alignment: .top, spacing: 0) {
                    // Time label
                    Text(h < 24 ? hourLabel(h) : "")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .frame(width: timeW, alignment: .trailing)
                        .padding(.trailing, 8)
                        .offset(y: -7)

                    // Divider + tap target
                    VStack(spacing: 0) {
                        Divider()
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if h < 24 {
                            tappedHour = h
                            showAddTask = true
                        }
                    }
                }
                .frame(height: hourH)
                .id(h)
            }
        }
    }

    // MARK: - Tasks layer
    private var tasksLayer: some View {
        let dayTasks = store.tasksForDate(selectedDate)
        return ZStack(alignment: .topLeading) {
            ForEach(dayTasks) { task in
                if let time = task.scheduledTime {
                    positionedBlock(task: task, time: time)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func positionedBlock(task: PlannerTask, time: Date) -> some View {
        let cal     = Calendar.current
        let h       = cal.component(.hour,   from: time)
        let m       = cal.component(.minute, from: time)
        let yOff    = CGFloat(h) * hourH + CGFloat(m) / 60.0 * hourH
        let blkH    = max(CGFloat(task.duration) / 60.0 * hourH, 36)

        return TaskBlockView(task: task)
            .frame(height: blkH)
            .padding(.leading, timeW + 8)
            .padding(.trailing, 16)
            .offset(y: yOff)
            .onTapGesture { store.toggleComplete(task) }
            .contextMenu {
                Button("Move to Inbox") { store.moveTaskToInbox(task) }
                Divider()
                Button("Delete", role: .destructive) { store.deleteTask(task) }
            }
    }

    // MARK: - Current time indicator (red line)
    private var currentTimeLine: some View {
        let now = Date()
        let h   = Calendar.current.component(.hour,   from: now)
        let m   = Calendar.current.component(.minute, from: now)
        let y   = CGFloat(h) * hourH + CGFloat(m) / 60.0 * hourH

        return HStack(spacing: 0) {
            Circle()
                .fill(.red)
                .frame(width: 8, height: 8)
                .padding(.leading, timeW + 2)
            Rectangle()
                .fill(.red)
                .frame(height: 1.5)
        }
        .offset(y: y)
        .allowsHitTesting(false)
    }

    // MARK: - Helpers
    private func shiftDay(_ delta: Int) {
        selectedDate = Calendar.current.date(byAdding: .day, value: delta, to: selectedDate) ?? selectedDate
    }

    private func hourLabel(_ h: Int) -> String {
        switch h {
        case 0:  return "12 AM"
        case 12: return "12 PM"
        default: return h < 12 ? "\(h) AM" : "\(h - 12) PM"
        }
    }

    private func hourAsDate(_ h: Int) -> Date {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: selectedDate)
        comps.hour   = h
        comps.minute = 0
        return Calendar.current.date(from: comps) ?? Date()
    }
}
