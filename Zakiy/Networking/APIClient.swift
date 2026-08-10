import Foundation

enum APIError: LocalizedError {
    case server(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .server(let message): return message
        case .invalidResponse: return Loc.t("err_unexpected_response")
        }
    }
}

@MainActor
final class APIClient {
    static let shared = APIClient()
    private let session = URLSession.shared
    private let decoder = JSONDecoder()

    private init() {}

    private func authorizedRequest(_ path: String, method: String = "GET") -> URLRequest {
        var request = URLRequest(url: APIConfig.apiBase.appendingPathComponent(path))
        request.httpMethod = method
        if let token = SupabaseAuthManager.shared.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func send<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)
        try Self.checkForServerError(data: data, response: response)
        return try decoder.decode(T.self, from: data)
    }

    private func sendVoid(_ request: URLRequest) async throws {
        let (data, response) = try await session.data(for: request)
        try Self.checkForServerError(data: data, response: response)
    }

    private static func checkForServerError(data: Data, response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            if let body = try? JSONDecoder().decode([String: String].self, from: data),
               let message = body["error"] {
                throw APIError.server(message)
            }
            throw APIError.server(Loc.t("err_server_status", http.statusCode))
        }
    }

    private func jsonBody(_ request: inout URLRequest, _ payload: [String: Any]) {
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
    }

    func upload(fileURL: URL) async throws -> String {
        var request = authorizedRequest("/api/upload", method: "POST")
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let fileData = try Data(contentsOf: fileURL)
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileURL.lastPathComponent)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/pdf\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        struct UploadResponse: Decodable { let filename: String }
        let result: UploadResponse = try await send(request)
        return result.filename
    }

    func extractText(filename: String) async throws -> String {
        var request = authorizedRequest("/api/extract", method: "POST")
        jsonBody(&request, ["filename": filename])
        struct ExtractResponse: Decodable { let text: String }
        let result: ExtractResponse = try await send(request)
        return result.text
    }

    func summarize(text: String, lang: String) async throws -> String {
        var request = authorizedRequest("/api/summarize", method: "POST")
        jsonBody(&request, ["text": text, "lang": lang])
        struct SummaryResponse: Decodable { let summary: String }
        let result: SummaryResponse = try await send(request)
        return result.summary
    }

    /// The backend returns `quiz_raw` as a JSON-array *string* (not markdown) whose shape already
    /// matches `QuizQuestion`'s coding keys exactly — no separate text parser needed. The model
    /// occasionally wraps it in ```json fences despite being told not to, so we defensively slice
    /// out the outermost `[...]` before decoding.
    func generateQuiz(text: String, numQuestions: Int, lang: String) async throws -> [QuizQuestion] {
        var request = authorizedRequest("/api/generate-quiz", method: "POST")
        jsonBody(&request, ["text": text, "num_questions": numQuestions, "lang": lang])
        struct QuizResponse: Decodable { let quizRaw: String; enum CodingKeys: String, CodingKey { case quizRaw = "quiz_raw" } }
        let result: QuizResponse = try await send(request)

        guard let start = result.quizRaw.firstIndex(of: "["), let end = result.quizRaw.lastIndex(of: "]"), start <= end else {
            throw APIError.invalidResponse
        }
        let jsonSlice = String(result.quizRaw[start...end])
        guard let data = jsonSlice.data(using: .utf8) else { throw APIError.invalidResponse }
        return try JSONDecoder().decode([QuizQuestion].self, from: data)
    }

    /// The backend threads a conversation via a server-side `interaction_id` (pass the one from
    /// the previous reply to continue the same thread) rather than us resending full history.
    /// `context`/`name` are only used to seed the very first turn (`interactionId == nil`).
    func chat(message: String, context: String?, name: String?, interactionId: String?, lang: String) async throws -> (reply: String, interactionId: String) {
        var request = authorizedRequest("/api/chat", method: "POST")
        var payload: [String: Any] = ["message": message, "lang": lang]
        if let interactionId { payload["interaction_id"] = interactionId }
        if let context { payload["context"] = context }
        if let name { payload["name"] = name }
        jsonBody(&request, payload)
        struct ChatResponse: Decodable { let reply: String; let interactionId: String; enum CodingKeys: String, CodingKey { case reply; case interactionId = "interaction_id" } }
        let result: ChatResponse = try await send(request)
        return (result.reply, result.interactionId)
    }

    func libraryBooks() async throws -> [LibraryBook] {
        struct Response: Decodable { let books: [LibraryBook] }
        let result: Response = try await send(authorizedRequest("/api/library"))
        return result.books
    }

    func libraryBook(id: String) async throws -> LibraryBookDetail {
        try await send(authorizedRequest("/api/library/\(id)"))
    }

    func createLibraryBook(title: String, extractedText: String) async throws -> String {
        var request = authorizedRequest("/api/library", method: "POST")
        jsonBody(&request, ["title": title, "extracted_text": extractedText])
        struct Response: Decodable { let id: String }
        let result: Response = try await send(request)
        return result.id
    }

    func renameLibraryBook(id: String, title: String) async throws {
        var request = authorizedRequest("/api/library/\(id)", method: "PATCH")
        jsonBody(&request, ["title": title])
        try await sendVoid(request)
    }

    func deleteLibraryBook(id: String) async throws {
        try await sendVoid(authorizedRequest("/api/library/\(id)", method: "DELETE"))
    }

    func syncProfile(username: String) async throws {
        var request = authorizedRequest("/api/profile/sync", method: "POST")
        jsonBody(&request, ["username": username])
        try await sendVoid(request)
    }

    func fullProfile(userId: String) async throws -> UserProfile {
        try await send(authorizedRequest("/api/profile/\(userId)"))
    }

    func updateMyProfile(_ patch: [String: Any]) async throws {
        var request = authorizedRequest("/api/profile", method: "PATCH")
        jsonBody(&request, patch)
        try await sendVoid(request)
    }

    func searchFriends(query: String) async throws -> [Friend] {
        var components = URLComponents(url: APIConfig.apiBase.appendingPathComponent("/api/friends/search"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "q", value: query)]
        var request = authorizedRequest("/api/friends/search")
        request.url = components.url
        struct Response: Decodable { let results: [Friend] }
        let result: Response = try await send(request)
        return result.results
    }

    func sendFriendRequest(toUserId: String) async throws {
        var request = authorizedRequest("/api/friends/request", method: "POST")
        jsonBody(&request, ["to_user_id": toUserId])
        try await sendVoid(request)
    }

    func friendRequests() async throws -> (incoming: [FriendRequest], outgoing: [FriendRequest]) {
        struct Response: Decodable { let incoming: [FriendRequest]; let outgoing: [FriendRequest] }
        let result: Response = try await send(authorizedRequest("/api/friends/requests"))
        return (result.incoming, result.outgoing)
    }

    func acceptFriendRequest(requestId: String) async throws {
        var request = authorizedRequest("/api/friends/accept", method: "POST")
        jsonBody(&request, ["request_id": requestId])
        try await sendVoid(request)
    }

    func rejectFriendRequest(requestId: String) async throws {
        var request = authorizedRequest("/api/friends/reject", method: "POST")
        jsonBody(&request, ["request_id": requestId])
        try await sendVoid(request)
    }

    func friends() async throws -> [Friend] {
        struct Response: Decodable { let friends: [Friend] }
        let result: Response = try await send(authorizedRequest("/api/friends"))
        return result.friends
    }

    func removeFriend(userId: String) async throws {
        try await sendVoid(authorizedRequest("/api/friends/\(userId)", method: "DELETE"))
    }

    func sendSessionInvite(toUserId: String, roomCode: String, roomType: String) async throws {
        var request = authorizedRequest("/api/friends/invite", method: "POST")
        jsonBody(&request, ["to_user_id": toUserId, "room_code": roomCode, "room_type": roomType])
        try await sendVoid(request)
    }

    func sessionInvites() async throws -> [SessionInvite] {
        struct Response: Decodable { let invites: [SessionInvite] }
        let result: Response = try await send(authorizedRequest("/api/friends/invites"))
        return result.invites
    }

    func dismissSessionInvite(id: String) async throws {
        try await sendVoid(authorizedRequest("/api/friends/invites/\(id)", method: "DELETE"))
    }

    func sessionsArchive() async throws -> [SessionArchiveItem] {
        struct Response: Decodable { let sessions: [SessionArchiveItem] }
        let result: Response = try await send(authorizedRequest("/api/sessions"))
        return result.sessions
    }

    func performance() async throws -> PerformanceData {
        try await send(authorizedRequest("/api/performance"))
    }

    /// Records "opened the app today" for the daily streak — safe to call once per session;
    /// the backend itself dedupes to one row per user per day.
    func pingActive() async throws {
        try await sendVoid(authorizedRequest("/api/ping-active", method: "POST"))
    }

    func recordQuizAttempt(score: Int, total: Int, timeTaken: Int, wrongTopics: [String], mode: String = "solo") async throws {
        var request = authorizedRequest("/api/quiz-attempt", method: "POST")
        jsonBody(&request, ["score": score, "total": total, "time_taken": timeTaken, "wrong_topics": wrongTopics, "mode": mode])
        try await sendVoid(request)
    }

    func createRoom(roomType: String) async throws -> String {
        var request = authorizedRequest("/api/room/create", method: "POST")
        jsonBody(&request, ["room_type": roomType])
        struct Response: Decodable { let roomCode: String; enum CodingKeys: String, CodingKey { case roomCode = "room_code" } }
        let result: Response = try await send(request)
        return result.roomCode
    }
}
