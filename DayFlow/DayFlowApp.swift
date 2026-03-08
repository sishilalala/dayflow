import SwiftUI

@main
struct DayFlowApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    // Handle Google OAuth callback: dayflow://oauth/google?code=...
                    guard url.scheme == "dayflow", url.host == "oauth" else { return }
                    Task {
                        do {
                            try await GoogleTasksService.handleCallback(url: url)
                        } catch {
                            print("OAuth error: \(error.localizedDescription)")
                        }
                    }
                }
        }
    }
}
