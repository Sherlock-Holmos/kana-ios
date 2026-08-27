import Foundation

/// SupabaseClient — minimal REST client (no SDK) that talks to a Supabase project
/// via PostgREST + GoTrue auth. Works on iOS 16+ with only Foundation / URLSession.
struct SupabaseClient {
    enum ClientError: Error, LocalizedError {
        case badURL(String)
        case http(Int, String)
        case decoding(Error)
        case noData

        var errorDescription: String? {
            switch self {
            case .badURL(let s):     return "无效 URL：\(s)"
            case .http(let c, let b): return "HTTP \(c): \(b)"
            case .decoding(let e):    return "解码失败：\(e.localizedDescription)"
            case .noData:             return "空响应"
            }
        }
    }

    let baseURL: URL
    let anonKey: String
    var token: String?

    init(url: String, anonKey: String, token: String? = nil) throws {
        guard let u = URL(string: url) else { throw ClientError.badURL(url) }
        self.baseURL = u
        self.anonKey = anonKey
        self.token = token
    }

    private var authHeader: String { "Bearer \(token ?? anonKey)" }
    private var apiKeyHeader: String { anonKey }

    private func request(_ path: String, method: String = "GET", body: Data? = nil, query: [URLQueryItem] = []) throws -> URLRequest {
        var comps = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        if !query.isEmpty { comps?.queryItems = query }
        guard let url = comps?.url else { throw ClientError.badURL(path) }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue(authHeader, forHTTPHeaderField: "Authorization")
        req.setValue(apiKeyHeader, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body { req.httpBody = body }
        return req
    }

    // MARK: - Auth

    struct AuthResponse: Decodable {
        let access_token: String
        let refresh_token: String?
        let user: User
        struct User: Decodable {
            let id: String
            let email: String
        }
    }

    func signIn(email: String, password: String) async throws -> SyncUser {
        let body = try JSONEncoder().encode(["email": email, "password": password])
        var req = try request("/auth/v1/token?grant_type=password", method: "POST", body: body)
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        return try await performAuth(req)
    }

    func signUp(email: String, password: String) async throws -> SyncUser {
        let body = try JSONEncoder().encode(["email": email, "password": password])
        let req = try request("/auth/v1/signup", method: "POST", body: body)
        return try await performAuth(req)
    }

    private func performAuth(_ req: URLRequest) async throws -> SyncUser {
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw ClientError.noData }
        guard (200..<300).contains(http.statusCode) else {
            throw ClientError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        do {
            let r = try JSONDecoder().decode(AuthResponse.self, from: data)
            self.token = r.access_token
            return SyncUser(id: r.user.id, email: r.user.email)
        } catch {
            throw ClientError.decoding(error)
        }
    }

    // MARK: - Sync (PostgREST)

    func upsertUserMeta(userId: String, schema: Int, envelope: SyncEnvelope) async throws {
        let payload: [String: Any] = [
            "user_id": userId,
            "schema_version": schema,
            "meta": [
                "srsCards": envelope.srsCards ?? [:],
                "abilities": envelope.abilities ?? [:],
                "activityByDay": envelope.activityByDay ?? [:],
                "dailyGoal": envelope.dailyGoal ?? 20,
                "bktMasteries": envelope.bktMasteries ?? [:]
            ],
            "updated_at": ISO8601DateFormatter().string(from: envelope.updatedAt)
        ]
        let body = try JSONSerialization.data(withJSONObject: payload)
        let req = try request("/rest/v1/user_learning_meta", method: "POST", body: body,
                              query: [URLQueryItem(name: "on_conflict", value: "user_id")])
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw ClientError.noData }
        guard (200..<300).contains(http.statusCode) else {
            throw ClientError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
    }

    func fetchUserMeta(userId: String, schema: Int) async throws -> SyncEnvelope? {
        let req = try request("/rest/v1/user_learning_meta", method: "GET",
                              query: [
                                URLQueryItem(name: "user_id", value: "eq.\(userId)"),
                                URLQueryItem(name: "select", value: "schema_version,meta,updated_at"),
                                URLQueryItem(name: "limit", value: "1")
                              ])
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw ClientError.noData }
        guard (200..<300).contains(http.statusCode) else {
            throw ClientError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        guard !data.isEmpty else { return nil }

        struct Row: Decodable {
            let schema_version: Int
            let meta: Meta
            let updated_at: String

            struct Meta: Decodable {
                let srsCards: [String: SRSCard]?
                let abilities: [String: Ability]?
                let activityByDay: [String: Int]?
                let dailyGoal: Int?
                let bktMasteries: [String: BKTMastery]?
            }
        }
        let decoder = JSONDecoder()
        let rows = try decoder.decode([Row].self, from: data)
        guard let row = rows.first else { return nil }
        let updated = ISO8601DateFormatter().date(from: row.updated_at) ?? Date()
        return SyncEnvelope(
            meta: nil,
            srsCards: row.meta.srsCards,
            abilities: row.meta.abilities,
            activityByDay: row.meta.activityByDay,
            dailyGoal: row.meta.dailyGoal,
            bktMasteries: row.meta.bktMasteries,
            updatedAt: updated
        )
    }
}