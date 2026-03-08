import Foundation

// MARK: - GoogleTasksService
// Uses OAuth 2.0 PKCE flow (no client secret needed for iOS native apps).
// User sets up a Google Cloud project once via Settings → Google Tasks.

class GoogleTasksService {

    // MARK: - Keychain/Defaults keys
    private enum Key {
        static let accessToken  = "goog_access_token"
        static let refreshToken = "goog_refresh_token"
        static let expiry       = "goog_token_expiry"
        static let clientId     = "goog_client_id"
    }

    // MARK: - OAuth constants
    static let redirectScheme = "dayflow"
    static let redirectURI    = "dayflow://oauth/google"
    static let scope          = "https://www.googleapis.com/auth/tasks"

    // MARK: - Authorization state
    static var isAuthorized: Bool {
        UserDefaults.standard.string(forKey: Key.refreshToken) != nil
    }

    static var savedClientId: String {
        UserDefaults.standard.string(forKey: Key.clientId) ?? ""
    }

    static func saveClientId(_ id: String) {
        UserDefaults.standard.set(id, forKey: Key.clientId)
    }

    // MARK: - Build auth URL (user opens this in Safari)
    static func authURL() -> URL? {
        guard !savedClientId.isEmpty else { return nil }
        var c = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        c.queryItems = [
            .init(name: "client_id",     value: savedClientId),
            .init(name: "redirect_uri",  value: redirectURI),
            .init(name: "response_type", value: "code"),
            .init(name: "scope",         value: scope),
            .init(name: "access_type",   value: "offline"),
            .init(name: "prompt",        value: "consent")
        ]
        return c.url
    }

    // MARK: - Handle OAuth callback (called from App onOpenURL)
    static func handleCallback(url: URL) async throws {
        guard
            let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let code  = comps.queryItems?.first(where: { $0.name == "code" })?.value
        else { throw GoogleError.invalidCallback }

        try await exchangeCode(code)
    }

    // Exchange auth code → access + refresh tokens
    private static func exchangeCode(_ code: String) async throws {
        var req = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        // Note: iOS "native" OAuth client IDs don't require a client_secret.
        // If Google requires it for your project type, add it here.
        let body = "code=\(code)"
            + "&client_id=\(savedClientId)"
            + "&redirect_uri=\(redirectURI)"
            + "&grant_type=authorization_code"
        req.httpBody = body.data(using: .utf8)

        let (data, _) = try await URLSession.shared.data(for: req)
        let resp = try JSONDecoder().decode(TokenResponse.self, from: data)
        storeTokens(resp)
    }

    // Refresh the access token silently
    private static func refreshAccessToken() async throws {
        guard let rt = UserDefaults.standard.string(forKey: Key.refreshToken) else {
            throw GoogleError.notAuthorized
        }
        var req = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = "refresh_token=\(rt)&client_id=\(savedClientId)&grant_type=refresh_token"
        req.httpBody = body.data(using: .utf8)

        let (data, _) = try await URLSession.shared.data(for: req)
        let resp = try JSONDecoder().decode(TokenResponse.self, from: data)
        storeTokens(resp)
    }

    private static func storeTokens(_ resp: TokenResponse) {
        let ud = UserDefaults.standard
        ud.set(resp.access_token, forKey: Key.accessToken)
        if let rt = resp.refresh_token { ud.set(rt, forKey: Key.refreshToken) }
        ud.set(Date().addingTimeInterval(TimeInterval(resp.expires_in - 60)), forKey: Key.expiry)
    }

    // Returns a valid access token (refreshes automatically if expired)
    private static func validToken() async throws -> String {
        let ud = UserDefaults.standard
        if let expiry = ud.object(forKey: Key.expiry) as? Date,
           expiry > Date(),
           let token = ud.string(forKey: Key.accessToken) {
            return token
        }
        try await refreshAccessToken()
        return ud.string(forKey: Key.accessToken) ?? ""
    }

    static func signOut() {
        [Key.accessToken, Key.refreshToken, Key.expiry].forEach {
            UserDefaults.standard.removeObject(forKey: $0)
        }
    }

    // MARK: - Fetch all tasks across all task lists
    func fetchAllTasks() async throws -> [PlannerTask] {
        let token = try await Self.validToken()
        let lists = try await fetchTaskLists(token: token)
        var all: [PlannerTask] = []
        for list in lists {
            let tasks = try await fetchTasks(listId: list.id, token: token)
            all.append(contentsOf: tasks)
        }
        return all
    }

    private func fetchTaskLists(token: String) async throws -> [GoogleTaskList] {
        let url = URL(string: "https://tasks.googleapis.com/tasks/v1/users/@me/lists")!
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: req)
        let resp = try JSONDecoder().decode(TaskListsResponse.self, from: data)
        return resp.items ?? []
    }

    private func fetchTasks(listId: String, token: String) async throws -> [PlannerTask] {
        let encoded = listId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? listId
        let url = URL(string: "https://tasks.googleapis.com/tasks/v1/lists/\(encoded)/tasks?showCompleted=false&showHidden=false")!
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: req)
        let resp = try JSONDecoder().decode(GoogleTasksListResponse.self, from: data)

        return (resp.items ?? []).map { item in
            var due: Date? = nil
            if let s = item.due {
                due = ISO8601DateFormatter().date(from: s)
            }
            return PlannerTask(
                title:    item.title,
                notes:    item.notes,
                source:   .googleTasks,
                sourceId: item.id,
                category: .work,
                dueDate:  due
            )
        }
    }

    // MARK: - Create
    func createTask(title: String, notes: String? = nil, dueDate: Date? = nil, listId: String = "@default") async throws {
        let token = try await Self.validToken()
        var body: [String: Any] = ["title": title]
        if let n = notes   { body["notes"] = n }
        if let d = dueDate { body["due"]   = ISO8601DateFormatter().string(from: d) }

        let encoded = listId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? listId
        var req = URLRequest(url: URL(string: "https://tasks.googleapis.com/tasks/v1/lists/\(encoded)/tasks")!)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json",  forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        _ = try await URLSession.shared.data(for: req)
    }

    // MARK: - Complete
    func completeTask(taskId: String, listId: String = "@default") async throws {
        let token   = try await Self.validToken()
        let listEnc = listId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? listId
        let taskEnc = taskId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? taskId
        var req = URLRequest(url: URL(string: "https://tasks.googleapis.com/tasks/v1/lists/\(listEnc)/tasks/\(taskEnc)")!)
        req.httpMethod = "PATCH"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json",  forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["status": "completed"])
        _ = try await URLSession.shared.data(for: req)
    }
}

// MARK: - Response Models

private struct TokenResponse: Codable {
    let access_token:  String
    let refresh_token: String?
    let expires_in:    Int
}

private struct TaskListsResponse: Codable {
    let items: [GoogleTaskList]?
}

struct GoogleTaskList: Codable {
    let id: String
    let title: String
}

private struct GoogleTasksListResponse: Codable {
    let items: [GoogleTaskItem]?
}

private struct GoogleTaskItem: Codable {
    let id:     String
    let title:  String
    let notes:  String?
    let due:    String?
    let status: String?
}

// MARK: - Errors
enum GoogleError: LocalizedError {
    case notAuthorized
    case invalidCallback
    case missingClientId

    var errorDescription: String? {
        switch self {
        case .notAuthorized:   return "Not signed in to Google. Please connect in Settings."
        case .invalidCallback: return "Invalid OAuth callback URL."
        case .missingClientId: return "Google Client ID not set. Please add it in Settings."
        }
    }
}
