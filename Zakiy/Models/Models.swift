import Foundation

struct QuizQuestion: Identifiable, Codable, Hashable {
    var id: String { question }
    let question: String
    let options: [String]
    let correctAnswer: String
    let topic: String
    let explanation: String

    enum CodingKeys: String, CodingKey {
        case question, options, topic, explanation
        case correctAnswer = "correct_answer"
    }
}

struct SessionRating: Codable, Equatable {
    let stars: Int
    let label: String
    let fast: Bool
}

struct LibraryBook: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, title
        case createdAt = "created_at"
    }
}

struct LibraryBookDetail: Codable {
    let title: String
    let extractedText: String

    enum CodingKeys: String, CodingKey {
        case title
        case extractedText = "extracted_text"
    }
}

struct QuizAttempt: Identifiable, Codable, Equatable {
    var id: String { (createdAt ?? "") + mode + String(score) }
    let mode: String
    let score: Int
    let total: Int
    let timeTaken: Int?
    let wrongTopics: [String]?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case mode, score, total
        case timeTaken = "time_taken"
        case wrongTopics = "wrong_topics"
        case createdAt = "created_at"
    }
}

struct WeakTopic: Identifiable, Codable, Equatable {
    var id: String { topic }
    let topic: String
    let count: Int
}

struct PerformanceData: Codable {
    let currentStreak: Int
    let longestStreak: Int
    let totalStudyMinutes: Int
    let attempts: [QuizAttempt]
    let weakTopics: [WeakTopic]

    enum CodingKeys: String, CodingKey {
        case currentStreak = "current_streak"
        case longestStreak = "longest_streak"
        case totalStudyMinutes = "total_study_minutes"
        case attempts
        case weakTopics = "weak_topics"
    }
}

struct Friend: Identifiable, Codable, Equatable {
    var id: String { userId }
    let userId: String
    let username: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case username
    }
}

struct FriendRequest: Identifiable, Decodable, Equatable {
    let id: String
    let username: String
    let createdAt: String?
    var otherUserId: String?

    enum CodingKeys: String, CodingKey {
        case id, username
        case createdAt = "created_at"
        case senderId = "sender_id"
        case receiverId = "receiver_id"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        username = try c.decode(String.self, forKey: .username)
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
        otherUserId = try c.decodeIfPresent(String.self, forKey: .senderId)
            ?? (try c.decodeIfPresent(String.self, forKey: .receiverId))
    }
}

func decodeFlexibleId(_ container: KeyedDecodingContainer<AnyCodingKey>, key: String) throws -> String {
    let codingKey = AnyCodingKey(stringValue: key)!
    if let s = try? container.decode(String.self, forKey: codingKey) { return s }
    if let i = try? container.decode(Int.self, forKey: codingKey) { return String(i) }
    return try container.decode(String.self, forKey: codingKey)
}

struct AnyCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { self.stringValue = String(intValue); self.intValue = intValue }
}

struct SessionInvite: Identifiable, Decodable, Hashable {
    let id: String
    let roomCode: String
    let roomType: String
    let fromUsername: String?

    enum CodingKeys: String, CodingKey {
        case id
        case roomCode = "room_code"
        case roomType = "room_type"
        case fromUsername = "from_username"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let anyContainer = try decoder.container(keyedBy: AnyCodingKey.self)
        id = try decodeFlexibleId(anyContainer, key: "id")
        roomCode = try c.decode(String.self, forKey: .roomCode)
        roomType = try c.decode(String.self, forKey: .roomType)
        fromUsername = try c.decodeIfPresent(String.self, forKey: .fromUsername)
    }
}

struct UserProfile: Decodable {
    let userId: String
    let username: String
    let isOwner: Bool
    let friendStatus: String
    let isPrivate: Bool
    let bio: String?
    let schoolName: String?
    let showPerformance: Bool?
    let showLibrary: Bool?
    let showArchive: Bool?
    let showFriends: Bool?
    let performance: ProfilePerformanceSummary?
    let library: ProfileLibrarySummary?
    let archive: [SessionArchiveItem]?
    let friends: ProfileFriendsSummary?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case username
        case isOwner = "is_owner"
        case friendStatus = "friend_status"
        case isPrivate = "is_private"
        case bio
        case schoolName = "school_name"
        case showPerformance = "show_performance"
        case showLibrary = "show_library"
        case showArchive = "show_archive"
        case showFriends = "show_friends"
        case performance, library, archive, friends
    }
}

struct ProfilePerformanceSummary: Decodable {
    let attemptsCount: Int
    let avgScore: Int
    let totalStudyMinutes: Int
    let currentStreak: Int

    enum CodingKeys: String, CodingKey {
        case attemptsCount = "attempts_count"
        case avgScore = "avg_score"
        case totalStudyMinutes = "total_study_minutes"
        case currentStreak = "current_streak"
    }
}

struct ProfileLibrarySummary: Decodable {
    let count: Int
    let titles: [String]
}

struct ProfileFriendsSummary: Decodable {
    let count: Int
    let list: [Friend]
}

struct SessionArchiveItem: Identifiable, Codable, Equatable {
    let id: String
    let roomCode: String?
    let roomType: String?
    let hostName: String?
    let hostUserId: String?
    let participants: [ArchiveParticipant]?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case roomCode = "room_code"
        case roomType = "room_type"
        case hostName = "host_name"
        case hostUserId = "host_user_id"
        case participants
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let anyContainer = try decoder.container(keyedBy: AnyCodingKey.self)
        id = try decodeFlexibleId(anyContainer, key: "id")
        roomCode = try c.decodeIfPresent(String.self, forKey: .roomCode)
        roomType = try c.decodeIfPresent(String.self, forKey: .roomType)
        hostName = try c.decodeIfPresent(String.self, forKey: .hostName)
        hostUserId = try c.decodeIfPresent(String.self, forKey: .hostUserId)
        participants = try c.decodeIfPresent([ArchiveParticipant].self, forKey: .participants)
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encodeIfPresent(roomCode, forKey: .roomCode)
        try c.encodeIfPresent(roomType, forKey: .roomType)
        try c.encodeIfPresent(hostName, forKey: .hostName)
        try c.encodeIfPresent(hostUserId, forKey: .hostUserId)
        try c.encodeIfPresent(participants, forKey: .participants)
        try c.encodeIfPresent(createdAt, forKey: .createdAt)
    }
}

struct ArchiveParticipant: Codable, Equatable {
    let name: String?
    let userId: String?
    let score: Int?
    let total: Int?
    let timeTaken: Int?
    let finished: Bool?

    enum CodingKeys: String, CodingKey {
        case name
        case userId = "user_id"
        case score, total, finished
        case timeTaken = "time_taken"
    }
}

struct RoomParticipant: Identifiable, Codable, Equatable {
    var id: String { sid }
    let sid: String
    let name: String
    let score: Int
    let total: Int
    let finished: Bool
    let timeTaken: Int
    let clientId: String?
    let isCoHost: Bool
    let inVoice: Bool

    enum CodingKeys: String, CodingKey {
        case sid, name, score, total, finished
        case timeTaken = "time_taken"
        case clientId = "client_id"
        case isCoHost = "is_co_host"
        case inVoice = "in_voice"
    }
}

struct RoomChatMessage: Identifiable, Codable, Equatable {
    let id = UUID()
    let name: String
    let message: String
    let ts: Double

    enum CodingKeys: String, CodingKey {
        case name, message, ts
    }
}

struct RaisedHand: Identifiable, Codable, Equatable {
    var id: String { clientId }
    let clientId: String
    let name: String

    enum CodingKeys: String, CodingKey {
        case clientId = "client_id"
        case name
    }
}

struct BoardStroke: Codable, Equatable {
    var mode: String
    var points: [[Double]]?
    var color: String
    var width: Double?
    var text: String?
    var x: Double?
    var y: Double?
    var fontSize: Double?
}
