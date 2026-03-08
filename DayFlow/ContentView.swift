import SwiftUI

struct ContentView: View {

    @StateObject private var store = TaskStore()

    var body: some View {
        TabView {
            TimelineView()
                .tabItem {
                    Label("Today", systemImage: "calendar.day.timeline.left")
                }

            InboxView()
                .tabItem {
                    Label("Inbox", systemImage: "tray.fill")
                }
                .badge(store.inboxTasks.count > 0 ? store.inboxTasks.count : 0)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .environmentObject(store)
        .task {
            // Sync on every launch
            await store.syncAll()
        }
    }
}
