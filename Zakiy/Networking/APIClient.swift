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

    /// `classId` يربط الغرفة بفصل مدرسي (يخدم تسجيل الحضور التلقائي + إشعار
    /// "بدأت الحصة") - الباك إند يتحقق إن صاحب الطلب فعلًا معلم هذا الفصل بالذات
    /// قبل ما يقبل الربط، وإلا يتجاهله بصمت بدون ما يمنع إنشاء الغرفة.
    func createRoom(roomType: String, classId: String? = nil) async throws -> String {
        var request = authorizedRequest("/api/room/create", method: "POST")
        var payload: [String: Any] = ["room_type": roomType]
        if let classId { payload["class_id"] = classId }
        jsonBody(&request, payload)
        struct Response: Decodable { let roomCode: String; enum CodingKeys: String, CodingKey { case roomCode = "room_code" } }
        let result: Response = try await send(request)
        return result.roomCode
    }

    // MARK: - نظام إدارة حسابات المدارس (٥ أدوار)

    func me() async throws -> MeResponse {
        try await send(authorizedRequest("/api/me"))
    }

    func completePasswordChange() async throws {
        try await sendVoid(authorizedRequest("/api/me/complete-password-change", method: "POST"))
    }

    /// لا يحتاج توكن (يُنادى قبل تسجيل الدخول) - يحوّل اسم مستخدم طالب لبريده
    /// الاصطناعي عشان نقدر نسجّل دخوله بيه عبر Supabase (يتطلب بريد دايمًا).
    func resolveLoginIdentifier(_ identifier: String) async throws -> String {
        var request = URLRequest(url: APIConfig.apiBase.appendingPathComponent("/api/resolve-login-identifier"))
        request.httpMethod = "POST"
        jsonBody(&request, ["identifier": identifier])
        struct Response: Decodable { let email: String }
        let result: Response = try await send(request)
        return result.email
    }

    // ---- Admin ----

    func adminCreateSchool(name: String, adminEmail: String, maxAccounts: Int) async throws -> CreateSchoolResponse {
        var request = authorizedRequest("/api/admin/schools", method: "POST")
        jsonBody(&request, ["name": name, "admin_email": adminEmail, "max_accounts": maxAccounts])
        return try await send(request)
    }

    func adminSchools() async throws -> [School] {
        struct Response: Decodable { let schools: [School] }
        let result: Response = try await send(authorizedRequest("/api/admin/schools"))
        return result.schools
    }

    func adminSetSchoolActive(id: String, isActive: Bool) async throws {
        var request = authorizedRequest("/api/admin/schools/\(id)", method: "PATCH")
        jsonBody(&request, ["is_active": isActive])
        try await sendVoid(request)
    }

    func adminResetSchoolAdminPassword(schoolId: String) async throws -> GeneratedCredentials {
        try await send(authorizedRequest("/api/admin/schools/\(schoolId)/reset-admin-password", method: "POST"))
    }

    /// حذف مدرسة بالكامل (مو بس إيقافها) - يشيل صف المدرسة (cascade يشيل
    /// معه الفصول/الحصص/الحضور المرتبطة) ويحذف حسابات Auth لكل أعضائها
    func adminDeleteSchool(id: String) async throws {
        try await sendVoid(authorizedRequest("/api/admin/schools/\(id)", method: "DELETE"))
    }

    // ---- School Admin / School Administration ----

    func schoolInfo() async throws -> SchoolInfo {
        try await send(authorizedRequest("/api/school/info"))
    }

    func schoolAddTeacher(name: String, email: String) async throws -> GeneratedCredentials {
        var request = authorizedRequest("/api/school/teachers", method: "POST")
        jsonBody(&request, ["name": name, "email": email])
        return try await send(request)
    }

    func schoolTeachers() async throws -> [TeacherSummary] {
        struct Response: Decodable { let teachers: [TeacherSummary] }
        let result: Response = try await send(authorizedRequest("/api/school/teachers"))
        return result.teachers
    }

    func schoolDeleteAccount(userId: String) async throws {
        try await sendVoid(authorizedRequest("/api/school/accounts/\(userId)", method: "DELETE"))
    }

    /// يولّد كلمة سر عشوائية قوية جديدة لأي حساب تابع لمدرستك (معلم أو طالب)
    /// ويفعّل must_change_password تلقائيًا - كلمة السر تظهر مرة وحدة بس
    func schoolResetAccountPassword(userId: String) async throws -> AccountResetCredentials {
        try await send(authorizedRequest("/api/school/accounts/\(userId)/reset-password", method: "POST"))
    }

    func schoolCreateClass(name: String, teacherId: String?) async throws -> SchoolClass {
        var request = authorizedRequest("/api/school/classes", method: "POST")
        var payload: [String: Any] = ["name": name]
        if let teacherId { payload["teacher_id"] = teacherId }
        jsonBody(&request, payload)
        return try await send(request)
    }

    func schoolClasses() async throws -> [SchoolClass] {
        struct Response: Decodable { let classes: [SchoolClass] }
        let result: Response = try await send(authorizedRequest("/api/school/classes"))
        return result.classes
    }

    func schoolReassignClassTeacher(classId: String, teacherId: String?) async throws {
        var request = authorizedRequest("/api/school/classes/\(classId)", method: "PATCH")
        jsonBody(&request, ["teacher_id": teacherId as Any])
        try await sendVoid(request)
    }

    func schoolDeleteClass(classId: String) async throws {
        try await sendVoid(authorizedRequest("/api/school/classes/\(classId)", method: "DELETE"))
    }

    func schoolAddSchedule(classId: String, dayOfWeek: Int, startTime: String, endTime: String, subject: String) async throws {
        var request = authorizedRequest("/api/school/classes/\(classId)/schedule", method: "POST")
        jsonBody(&request, ["day_of_week": dayOfWeek, "start_time": startTime, "end_time": endTime, "subject": subject])
        try await sendVoid(request)
    }

    func schoolClassSchedule(classId: String) async throws -> [ClassScheduleEntry] {
        struct Response: Decodable { let schedule: [ClassScheduleEntry] }
        let result: Response = try await send(authorizedRequest("/api/school/classes/\(classId)/schedule"))
        return result.schedule
    }

    func schoolDeleteSchedule(id: String) async throws {
        try await sendVoid(authorizedRequest("/api/school/schedule/\(id)", method: "DELETE"))
    }

    func schoolBulkAddStudents(classId: String, names: [String]) async throws -> [GeneratedStudent] {
        var request = authorizedRequest("/api/school/students/bulk", method: "POST")
        jsonBody(&request, ["class_id": classId, "names": names])
        let result: BulkAddResponse = try await send(request)
        return result.students
    }

    func schoolStudents(classId: String? = nil) async throws -> [SchoolStudent] {
        var path = "/api/school/students"
        if let classId { path += "?class_id=\(classId)" }
        struct Response: Decodable { let students: [SchoolStudent] }
        let result: Response = try await send(authorizedRequest(path))
        return result.students
    }

    func schoolProfile(userId: String) async throws -> InstitutionalProfile {
        try await send(authorizedRequest("/api/school/profile/\(userId)"))
    }

    func schoolAttendance(classId: String? = nil) async throws -> SchoolAttendanceReport {
        var path = "/api/school/attendance"
        if let classId { path += "?class_id=\(classId)" }
        return try await send(authorizedRequest(path))
    }

    func schoolBroadcast(body: String) async throws -> Int {
        var request = authorizedRequest("/api/school/broadcast", method: "POST")
        jsonBody(&request, ["body": body])
        struct Response: Decodable { let sentTo: Int; enum CodingKeys: String, CodingKey { case sentTo = "sent_to" } }
        let result: Response = try await send(request)
        return result.sentTo
    }

    // ---- Teacher ----

    func teacherRoster() async throws -> TeacherRosterResponse {
        try await send(authorizedRequest("/api/teacher/roster"))
    }

    func teacherStudentProfile(userId: String) async throws -> InstitutionalProfile {
        try await send(authorizedRequest("/api/teacher/students/\(userId)"))
    }

    func teacherPerformance(classId: String? = nil) async throws -> [TeacherPerformanceRow] {
        var path = "/api/teacher/performance"
        if let classId { path += "?class_id=\(classId)" }
        let result: TeacherPerformanceResponse = try await send(authorizedRequest(path))
        return result.performance
    }

    func teacherSchedule() async throws -> TeacherScheduleResponse {
        try await send(authorizedRequest("/api/teacher/schedule"))
    }

    func teacherAttendance(classId: String? = nil) async throws -> [SessionAttendanceRow] {
        var path = "/api/teacher/attendance"
        if let classId { path += "?class_id=\(classId)" }
        let result: TeacherAttendanceResponse = try await send(authorizedRequest(path))
        return result.attendance
    }

    func teacherManualAttendance(classId: String, date: String) async throws -> [ManualAttendanceRecord] {
        struct Response: Decodable { let records: [ManualAttendanceRecord] }
        let result: Response = try await send(authorizedRequest("/api/teacher/attendance/manual?class_id=\(classId)&date=\(date)"))
        return result.records
    }

    func teacherSaveManualAttendance(classId: String, date: String, records: [(studentId: String, status: String)]) async throws {
        var request = authorizedRequest("/api/teacher/attendance/manual", method: "POST")
        let recordsPayload = records.map { ["student_id": $0.studentId, "status": $0.status] }
        jsonBody(&request, ["class_id": classId, "date": date, "records": recordsPayload])
        try await sendVoid(request)
    }

    func teacherBroadcast(body: String, classId: String? = nil) async throws -> Int {
        var request = authorizedRequest("/api/teacher/broadcast", method: "POST")
        var payload: [String: Any] = ["body": body]
        if let classId { payload["class_id"] = classId }
        jsonBody(&request, payload)
        struct Response: Decodable { let sentTo: Int; enum CodingKeys: String, CodingKey { case sentTo = "sent_to" } }
        let result: Response = try await send(request)
        return result.sentTo
    }

    // ---- Student ----

    func studentSchedule() async throws -> [ClassScheduleEntry] {
        let result: StudentScheduleResponse = try await send(authorizedRequest("/api/student/schedule"))
        return result.schedule
    }

    // ---- رسائل مباشرة + تنبيهات (لأي مستخدم مسجّل دخول) ----

    func conversations() async throws -> [ConversationSummary] {
        struct Response: Decodable { let conversations: [ConversationSummary] }
        let result: Response = try await send(authorizedRequest("/api/messages/conversations"))
        return result.conversations
    }

    func messageThread(otherUserId: String) async throws -> [DirectMessage] {
        struct Response: Decodable { let messages: [DirectMessage] }
        let result: Response = try await send(authorizedRequest("/api/messages/thread/\(otherUserId)"))
        return result.messages
    }

    func sendMessage(recipientId: String, body: String) async throws {
        var request = authorizedRequest("/api/messages/send", method: "POST")
        jsonBody(&request, ["recipient_id": recipientId, "body": body])
        try await sendVoid(request)
    }

    func notifications() async throws -> NotificationsResponse {
        try await send(authorizedRequest("/api/notifications"))
    }

    func markNotificationsRead() async throws {
        try await sendVoid(authorizedRequest("/api/notifications/mark-read", method: "POST"))
    }

    // ---- الاشتراكات ----

    /// يزامن نتيجة شراء StoreKit ناجح مع الباك إند - يخلي حساب المستخدم
    /// عارف بالباقة حتى لو دخل من جهاز/منصة ثانية (StoreManager يناديها بعد كل شراء).
    func subscriptionAppleVerify(productID: String, transactionID: String) async throws -> SubscriptionSyncResponse {
        var request = authorizedRequest("/api/subscription/apple/verify", method: "POST")
        jsonBody(&request, ["product_id": productID, "transaction_id": transactionID])
        return try await send(request)
    }
}
