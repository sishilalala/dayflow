import SwiftUI

struct SettingsView: View {

    @EnvironmentObject var store: TaskStore
    @State private var googleClientId = GoogleTasksService.savedClientId
    @State private var claudeKey      = UserDefaults.standard.string(forKey: "claude_api_key") ?? ""
    @State private var showGoogleHelp = false
    @State private var isSyncing      = false

    var body: some View {
        NavigationView {
            Form {
                // ── Apple Reminders ──────────────────────────────────────
                Section {
                    HStack {
                        Label("Apple Reminders", systemImage: "bell.fill")
                            .foregroundStyle(.orange)
                        Spacer()
                        if store.remindersAuthorized {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        }
                    }
                    Button("Sync Reminders Now") {
                        Task { await store.syncReminders() }
                    }
                } header: {
                    Text("Apple")
                } footer: {
                    Text("Access is requested the first time you sync. Tasks sync both ways — changes you make here reflect in Apple Reminders.")
                }

                // ── Google Tasks ─────────────────────────────────────────
                Section {
                    if GoogleTasksService.isAuthorized {
                        HStack {
                            Label("Google Tasks Connected", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Spacer()
                            Button("Disconnect") {
                                GoogleTasksService.signOut()
                            }
                            .foregroundStyle(.red)
                            .buttonStyle(.plain)
                        }
                        Button("Sync Google Tasks Now") {
                            Task { await store.syncGoogleTasks() }
                        }
                    } else {
                        HStack {
                            Label("Not Connected", systemImage: "circle")
                                .foregroundStyle(.secondary)
                        }

                        TextField("Google Client ID", text: $googleClientId)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.system(size: 14, design: .monospaced))

                        Button("Save & Connect Google") {
                            GoogleTasksService.saveClientId(googleClientId)
                            if let url = GoogleTasksService.authURL() {
                                UIApplication.shared.open(url)
                            }
                        }
                        .disabled(googleClientId.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } header: {
                    HStack {
                        Text("Google Tasks")
                        Spacer()
                        Button {
                            showGoogleHelp = true
                        } label: {
                            Image(systemName: "questionmark.circle")
                                .font(.system(size: 14))
                        }
                    }
                } footer: {
                    Text("Requires a free Google Cloud project with Tasks API enabled. Tap ? for setup guide.")
                }

                // ── AI (Claude) ──────────────────────────────────────────
                Section {
                    SecureField("Claude API Key  (sk-ant-...)", text: $claudeKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(size: 14, design: .monospaced))
                        .onChange(of: claudeKey) { v in
                            UserDefaults.standard.set(v, forKey: "claude_api_key")
                        }
                } header: {
                    Text("AI Features (Optional)")
                } footer: {
                    Text("Your key is stored only on this device and never sent to any server other than Anthropic. Get it at console.anthropic.com")
                }

                // ── Sync all ─────────────────────────────────────────────
                Section {
                    Button {
                        isSyncing = true
                        Task {
                            await store.syncAll()
                            isSyncing = false
                        }
                    } label: {
                        HStack {
                            if isSyncing { ProgressView().padding(.trailing, 4) }
                            Text(isSyncing ? "Syncing…" : "Sync Everything")
                        }
                    }
                    .disabled(isSyncing)
                }

                // ── About ────────────────────────────────────────────────
                Section("About") {
                    HStack {
                        Text("DayFlow")
                        Spacer()
                        Text("v0.1.0").foregroundStyle(.secondary)
                    }
                    Text("All data lives on your device.\nNo account. No tracking. No ads.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showGoogleHelp) { googleGuide }
        }
    }

    // MARK: - Google setup guide
    private var googleGuide: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Group {
                        stepRow(n: 1, text: "Go to **console.cloud.google.com** and sign in with your Google account.")
                        stepRow(n: 2, text: "Create a new project (or select an existing one).")
                        stepRow(n: 3, text: "Search for **\"Google Tasks API\"** and enable it.")
                        stepRow(n: 4, text: "Go to **APIs & Services → Credentials**.")
                        stepRow(n: 5, text: "Click **Create Credentials → OAuth 2.0 Client ID**.")
                        stepRow(n: 6, text: "Choose **iOS** as the application type.")
                        stepRow(n: 7, text: "Set Bundle ID to: `com.dayflow.app`")
                        stepRow(n: 8, text: "Copy the **Client ID** and paste it in Settings.")
                        stepRow(n: 9, text: "Tap **Save & Connect Google** — a browser window will open to authorise.")
                    }
                }
                .padding()
            }
            .navigationTitle("Google Setup Guide")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showGoogleHelp = false }.bold()
                }
            }
        }
    }

    private func stepRow(n: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(n)")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(.blue, in: Circle())
            Text(LocalizedStringKey(text))
                .font(.system(size: 15))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
