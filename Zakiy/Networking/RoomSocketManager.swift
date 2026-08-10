import Foundation
import SocketIO
import Observation

struct RoomState: Equatable {
    var roomCode: String = ""
    var createdAt: Double = 0
    var roomType: String = "quiz"
    var isHost: Bool = false
    var canManageContent: Bool = false
    var quiz: [QuizQuestion]?
    var quizStartedAt: Double?
    var durationMinutes: Double?
    var sharedSummary: String?
    var boardStrokes: [BoardStroke] = []
    var raisedHands: [RaisedHand] = []
    var classStarted: Bool = false
}

@MainActor
@Observable
final class RoomSocketManager {
    private var manager: SocketManager?
    private var socket: SocketIOClient?

    var isConnected = false
    var roomState = RoomState()
    var leaderboard: [RoomParticipant] = []
    var chatMessages: [RoomChatMessage] = []
    var typingNames: Set<String> = []
    var errorMessage: String?
    var wasKicked = false
    var forceMutedSignal = 0
    /// The display name we joined with — used purely client-side to tell "my own" chat bubbles
    /// apart from others' (the backend's chat_message event only carries a name, not a sid).
    private(set) var myName = ""

    static let persistentClientId: String = {
        let key = "zakiy.clientId"
        if let existing = UserDefaults.standard.string(forKey: key) { return existing }
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: key)
        return newId
    }()

    func connect(roomCode: String, name: String) {
        myName = name
        let manager = SocketManager(socketURL: APIConfig.apiBase, config: [.log(false), .compress, .forceWebsockets(true)])
        self.manager = manager
        let socket = manager.defaultSocket
        self.socket = socket

        registerHandlers(on: socket)

        socket.on(clientEvent: .connect) { [weak self] _, _ in
            Task { @MainActor in
                self?.isConnected = true
                self?.joinRoom(roomCode: roomCode, name: name)
            }
        }
        socket.on(clientEvent: .disconnect) { [weak self] _, _ in
            Task { @MainActor in self?.isConnected = false }
        }

        socket.connect()
    }

    func disconnect() {
        socket?.emit("voice_leave", ["room_code": roomState.roomCode])
        socket?.disconnect()
        socket = nil
        manager = nil
        isConnected = false
    }

    private func joinRoom(roomCode: String, name: String) {
        var payload: [String: Any] = [
            "room_code": roomCode,
            "name": name,
            "client_id": Self.persistentClientId,
        ]
        if let token = SupabaseAuthManager.shared.accessToken {
            payload["token"] = token
        }
        socket?.emit("join_room", payload)
    }

    func sendChatMessage(_ text: String) {
        socket?.emit("chat_message", ["room_code": roomState.roomCode, "message": text])
    }

    func sendTyping() { socket?.emit("typing", ["room_code": roomState.roomCode]) }
    func sendStopTyping() { socket?.emit("stop_typing", ["room_code": roomState.roomCode]) }

    func shareSummary(_ summary: String) {
        socket?.emit("share_summary", ["room_code": roomState.roomCode, "summary": summary])
    }

    func startQuiz(_ questions: [QuizQuestion], durationMinutes: Double) {
        let quizPayload = questions.map { q -> [String: Any] in
            [
                "question": q.question,
                "options": q.options,
                "correct_answer": q.correctAnswer,
                "topic": q.topic,
                "explanation": q.explanation,
            ]
        }
        socket?.emit("start_quiz", ["room_code": roomState.roomCode, "quiz": quizPayload, "duration_minutes": durationMinutes])
    }

    func submitScore(score: Int, total: Int, timeTaken: Int, wrongTopics: [String]) {
        socket?.emit("submit_score", [
            "room_code": roomState.roomCode,
            "score": score,
            "total": total,
            "time_taken": timeTaken,
            "wrong_topics": wrongTopics,
        ])
    }

    func grantPermission(sid: String) { socket?.emit("grant_permission", ["room_code": roomState.roomCode, "sid": sid]) }
    func revokePermission(sid: String) { socket?.emit("revoke_permission", ["room_code": roomState.roomCode, "sid": sid]) }
    func kickParticipant(sid: String) { socket?.emit("kick_participant", ["room_code": roomState.roomCode, "sid": sid]) }
    func forceMute(sid: String) { socket?.emit("force_mute_participant", ["room_code": roomState.roomCode, "sid": sid]) }

    func startClass() { socket?.emit("start_class", ["room_code": roomState.roomCode]) }
    func raiseHand() { socket?.emit("raise_hand", ["room_code": roomState.roomCode]) }
    func luckyDraw() { socket?.emit("lucky_draw", ["room_code": roomState.roomCode]) }

    func sendBoardStroke(_ stroke: BoardStroke) {
        var strokePayload: [String: Any] = [
            "mode": stroke.mode,
            "color": stroke.color,
        ]
        if let points = stroke.points { strokePayload["points"] = points }
        if let width = stroke.width { strokePayload["width"] = width }
        if let text = stroke.text { strokePayload["text"] = text }
        if let x = stroke.x { strokePayload["x"] = x }
        if let y = stroke.y { strokePayload["y"] = y }
        if let fontSize = stroke.fontSize { strokePayload["fontSize"] = fontSize }
        // The backend expects the stroke nested under a "stroke" key, not flattened into the payload.
        socket?.emit("board_stroke", ["room_code": roomState.roomCode, "stroke": strokePayload])
    }

    func clearBoard() { socket?.emit("board_clear", ["room_code": roomState.roomCode]) }

    func emitVoiceJoin() { socket?.emit("voice_join", ["room_code": roomState.roomCode]) }
    func emitVoiceLeave() { socket?.emit("voice_leave", ["room_code": roomState.roomCode]) }

    /// Voice signaling uses three distinct backend events (not a single generic one) — the
    /// server relays each payload opaquely to `to_sid`, so only the two ends of our own
    /// WebRTC manager need to agree on the shape of `offer`/`answer`/`candidate`.
    func emitVoiceOffer(to targetSid: String, sdp: String) {
        socket?.emit("voice_offer", ["to_sid": targetSid, "offer": ["type": "offer", "sdp": sdp]])
    }
    func emitVoiceAnswer(to targetSid: String, sdp: String) {
        socket?.emit("voice_answer", ["to_sid": targetSid, "answer": ["type": "answer", "sdp": sdp]])
    }
    func emitVoiceIceCandidate(to targetSid: String, candidate: String, sdpMid: String, sdpMLineIndex: Int) {
        socket?.emit("voice_ice_candidate", [
            "to_sid": targetSid,
            "candidate": ["candidate": candidate, "sdpMid": sdpMid, "sdpMLineIndex": sdpMLineIndex],
        ])
    }

    func onVoiceEvent(_ event: String, handler: @escaping ([String: Any]) -> Void) {
        socket?.on(event) { data, _ in
            guard let dict = data.first as? [String: Any] else { return }
            handler(dict)
        }
    }

    private func registerHandlers(on socket: SocketIOClient) {
        socket.on("join_error") { [weak self] data, _ in
            Task { @MainActor in self?.errorMessage = (data.first as? [String: Any])?["error"] as? String }
        }

        socket.on("room_state") { [weak self] data, _ in
            Task { @MainActor in self?.applyRoomState(data.first as? [String: Any]) }
        }

        socket.on("leaderboard_update") { [weak self] data, _ in
            Task { @MainActor in self?.applyLeaderboard(data.first as? [String: Any]) }
        }

        socket.on("chat_message") { [weak self] data, _ in
            Task { @MainActor in self?.applyChatMessage(data.first as? [String: Any]) }
        }

        socket.on("user_typing") { [weak self] data, _ in
            guard let name = (data.first as? [String: Any])?["name"] as? String else { return }
            Task { @MainActor in self?.typingNames.insert(name) }
        }

        socket.on("user_stop_typing") { [weak self] data, _ in
            guard let name = (data.first as? [String: Any])?["name"] as? String else { return }
            Task { @MainActor in self?.typingNames.remove(name) }
        }

        socket.on("permission_granted") { [weak self] _, _ in
            Task { @MainActor in self?.roomState.canManageContent = true }
        }
        socket.on("permission_revoked") { [weak self] _, _ in
            Task { @MainActor in self?.roomState.canManageContent = false }
        }

        socket.on("summary_shared") { [weak self] data, _ in
            guard let summary = (data.first as? [String: Any])?["summary"] as? String else { return }
            Task { @MainActor in self?.roomState.sharedSummary = summary }
        }

        socket.on("quiz_started") { [weak self] data, _ in
            guard let dict = data.first as? [String: Any] else { return }
            Task { @MainActor in
                if let quizArray = dict["quiz"] as? [[String: Any]] {
                    self?.roomState.quiz = quizArray.compactMap(Self.decodeQuizQuestion)
                }
                // The backend names this field "started_at" in the quiz_started event
                // (it's "quiz_started_at" only inside the room_state snapshot payload).
                self?.roomState.quizStartedAt = dict["started_at"] as? Double
                self?.roomState.durationMinutes = dict["duration_minutes"] as? Double
            }
        }

        socket.on("kicked") { [weak self] _, _ in
            Task { @MainActor in self?.wasKicked = true }
        }

        socket.on("force_muted") { [weak self] _, _ in
            Task { @MainActor in self?.forceMutedSignal += 1 }
        }

        socket.on("class_started_event") { [weak self] _, _ in
            Task { @MainActor in self?.roomState.classStarted = true }
        }

        socket.on("hands_update") { [weak self] data, _ in
            guard let dict = data.first as? [String: Any], let raised = dict["raised"] as? [[String: Any]] else { return }
            let hands = raised.compactMap { item -> RaisedHand? in
                guard let clientId = item["client_id"] as? String else { return nil }
                let name = item["name"] as? String ?? clientId
                return RaisedHand(clientId: clientId, name: name)
            }
            Task { @MainActor in self?.roomState.raisedHands = hands }
        }

        socket.on("board_stroke") { [weak self] data, _ in
            // The backend echoes the stroke back nested under a "stroke" key, matching what we send.
            guard let dict = data.first as? [String: Any],
                  let strokeDict = dict["stroke"] as? [String: Any],
                  let stroke = Self.decodeStroke(strokeDict) else { return }
            Task { @MainActor in self?.roomState.boardStrokes.append(stroke) }
        }

        socket.on("board_clear") { [weak self] _, _ in
            Task { @MainActor in self?.roomState.boardStrokes = [] }
        }

        socket.on("lucky_draw_result") { data, _ in
            guard let dict = data.first as? [String: Any] else { return }
            NotificationCenter.default.post(name: .init("zakiy.socket.lucky_draw_result"), object: dict)
        }
    }

    private func applyRoomState(_ dict: [String: Any]?) {
        guard let dict else { return }
        roomState.roomCode = dict["room_code"] as? String ?? roomState.roomCode
        roomState.createdAt = dict["created_at"] as? Double ?? roomState.createdAt
        roomState.roomType = dict["room_type"] as? String ?? roomState.roomType
        roomState.isHost = dict["is_host"] as? Bool ?? false
        roomState.canManageContent = dict["can_manage_content"] as? Bool ?? false
        roomState.quizStartedAt = dict["quiz_started_at"] as? Double
        roomState.durationMinutes = dict["duration_minutes"] as? Double
        roomState.sharedSummary = dict["shared_summary"] as? String
        roomState.classStarted = dict["class_started"] as? Bool ?? false

        if let quizArray = dict["quiz"] as? [[String: Any]] {
            roomState.quiz = quizArray.compactMap(Self.decodeQuizQuestion)
        }
        if let strokes = dict["board_strokes"] as? [[String: Any]] {
            roomState.boardStrokes = strokes.compactMap(Self.decodeStroke)
        }
        if let hands = dict["raised_hands"] as? [String] {
            roomState.raisedHands = hands.map { RaisedHand(clientId: $0, name: $0) }
        }
    }

    private func applyLeaderboard(_ dict: [String: Any]?) {
        guard let dict, let list = dict["leaderboard"] as? [[String: Any]] else { return }
        leaderboard = list.compactMap { item in
            guard let sid = item["sid"] as? String, let name = item["name"] as? String else { return nil }
            return RoomParticipant(
                sid: sid,
                name: name,
                score: item["score"] as? Int ?? 0,
                total: item["total"] as? Int ?? 0,
                finished: item["finished"] as? Bool ?? false,
                timeTaken: item["time_taken"] as? Int ?? 0,
                clientId: item["client_id"] as? String,
                isCoHost: item["is_co_host"] as? Bool ?? false,
                inVoice: item["in_voice"] as? Bool ?? false
            )
        }
    }

    private func applyChatMessage(_ dict: [String: Any]?) {
        guard let dict, let name = dict["name"] as? String, let message = dict["message"] as? String else { return }
        let ts = dict["ts"] as? Double ?? Date().timeIntervalSince1970
        chatMessages.append(RoomChatMessage(name: name, message: message, ts: ts))
    }

    private static func decodeQuizQuestion(_ dict: [String: Any]) -> QuizQuestion? {
        guard let question = dict["question"] as? String,
              let options = dict["options"] as? [String],
              let correctAnswer = dict["correct_answer"] as? String else { return nil }
        let topic = dict["topic"] as? String ?? ""
        let explanation = dict["explanation"] as? String ?? ""
        return QuizQuestion(question: question, options: options, correctAnswer: correctAnswer, topic: topic, explanation: explanation)
    }

    private static func decodeStroke(_ dict: [String: Any]) -> BoardStroke? {
        guard let mode = dict["mode"] as? String, let color = dict["color"] as? String else { return nil }
        return BoardStroke(
            mode: mode,
            points: dict["points"] as? [[Double]],
            color: color,
            width: dict["width"] as? Double,
            text: dict["text"] as? String,
            x: dict["x"] as? Double,
            y: dict["y"] as? Double,
            fontSize: dict["fontSize"] as? Double
        )
    }
}
