import Foundation

// MARK: - نظام إدارة حسابات المدارس (٥ أدوار) - نماذج تطابق شكل JSON اللي
// يرجّعه الباك إند بالضبط (backend/app.py) - نفس نمط التطابق الحرفي المتبع
// بباقي Models.swift (CodingKeys صريحة لكل حقل snake_case).

/// رد `/api/me` - أول شي يُطلب بعد الدخول لتحديد التوجيه. `role == nil` يعني
/// حساب فردي عادي (نفس تجربة التطبيق الحالية بدون أي تغيير).
struct MeResponse: Decodable {
    let role: String?
    let schoolId: String?
    let classId: String?
    let mustChangePassword: Bool
    let username: String?

    enum CodingKeys: String, CodingKey {
        case role
        case schoolId = "school_id"
        case classId = "class_id"
        case mustChangePassword = "must_change_password"
        case username
    }
}

enum AccountRole: String {
    case admin, schoolAdmin = "school_admin", schoolAdministration = "school_administration", teacher, student
}

struct School: Identifiable, Decodable {
    let id: String
    let name: String
    let maxAccounts: Int
    let subscriptionStatus: String?
    let subscriptionPackage: String?
    let isActive: Bool
    let createdAt: String?
    var accountsUsed: Int?
    var adminEmail: String?

    enum CodingKeys: String, CodingKey {
        case id, name
        case maxAccounts = "max_accounts"
        case subscriptionStatus = "subscription_status"
        case subscriptionPackage = "subscription_package"
        case isActive = "is_active"
        case createdAt = "created_at"
        case accountsUsed = "accounts_used"
        case adminEmail = "admin_email"
    }
}

struct GeneratedCredentials: Decodable {
    let email: String
    let password: String
}

/// نتيجة إعادة تعيين كلمة سر أي حساب بالمدرسة (معلم أو طالب) - "identifier"
/// عامّ لأن حساب الطالب يتعرّف باسم مستخدم لا بريد فعلي (مطابق لنفس مفتاح
/// JSON اللي يرجّعه /api/school/accounts/<id>/reset-password بالباك إند)
struct AccountResetCredentials: Decodable {
    let identifier: String
    let password: String
}

struct CreateSchoolResponse: Decodable {
    let school: School
    let schoolAdmin: GeneratedCredentials

    enum CodingKeys: String, CodingKey {
        case school
        case schoolAdmin = "school_admin"
    }
}

struct SchoolInfo: Decodable {
    let id: String
    let name: String
    let maxAccounts: Int
    let accountsUsed: Int
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case id, name
        case maxAccounts = "max_accounts"
        case accountsUsed = "accounts_used"
        case isActive = "is_active"
    }
}

struct SchoolClass: Identifiable, Decodable, Hashable {
    let id: String
    let name: String
    let teacherId: String?

    enum CodingKeys: String, CodingKey {
        case id, name
        case teacherId = "teacher_id"
    }
}

struct TeacherSummary: Identifiable, Decodable {
    var id: String { userId }
    let userId: String
    let username: String
    let fullName: String?
    let classes: [SchoolClass]
    let studentCount: Int
    let lastLogin: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case username
        case fullName = "full_name"
        case classes
        case studentCount = "student_count"
        case lastLogin = "last_login"
    }
}

struct SchoolStudent: Identifiable, Decodable, Hashable {
    var id: String { userId }
    let userId: String
    let username: String
    let fullName: String?
    let classId: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case username
        case fullName = "full_name"
        case classId = "class_id"
    }
}

struct ClassScheduleEntry: Identifiable, Decodable, Hashable {
    let id: String
    let classId: String?
    let dayOfWeek: Int
    let startTime: String
    let endTime: String
    let subject: String?

    enum CodingKeys: String, CodingKey {
        case id
        case classId = "class_id"
        case dayOfWeek = "day_of_week"
        case startTime = "start_time"
        case endTime = "end_time"
        case subject
    }
}

/// اسم يوم أسبوع مختصر بنفس ترقيم الباك إند (0 = الأحد .. 6 = السبت) -
/// نفس الترتيب المستخدم بموقع الويب بالضبط.
enum WeekDay {
    static func label(_ dayOfWeek: Int) -> String {
        let keys = ["day_0", "day_1", "day_2", "day_3", "day_4", "day_5", "day_6"]
        guard (0..<7).contains(dayOfWeek) else { return "?" }
        return Loc.t(keys[dayOfWeek])
    }
}

struct GeneratedStudent: Identifiable, Decodable {
    var id: String { username }
    let name: String
    let username: String
    let password: String
}

struct BulkAddResponse: Decodable {
    let students: [GeneratedStudent]
}

/// بروفايل مؤسسي (School Admin/Administration أو Teacher يفتحون بروفايل
/// طالب/معلم تحت إشرافهم) - بدون بوابات الخصوصية الاجتماعية العادية،
/// يرجعه كل من `/api/school/profile/<id>` و`/api/teacher/students/<id>`.
struct InstitutionalProfile: Decodable {
    let userId: String
    let username: String
    let fullName: String?
    let bio: String?
    let schoolName: String?
    let role: String?
    let performance: ProfilePerformanceSummary?
    let archive: [SessionArchiveItem]?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case username
        case fullName = "full_name"
        case bio
        case schoolName = "school_name"
        case role, performance, archive
    }
}

struct SessionAttendanceRow: Decodable, Hashable {
    let classId: String?
    let userId: String
    let joinedAt: String

    enum CodingKeys: String, CodingKey {
        case classId = "class_id"
        case userId = "user_id"
        case joinedAt = "joined_at"
    }
}

struct ManualAttendanceRow: Decodable, Hashable {
    let classId: String?
    let studentId: String
    let sessionDate: String?
    let status: String

    enum CodingKeys: String, CodingKey {
        case classId = "class_id"
        case studentId = "student_id"
        case sessionDate = "session_date"
        case status
    }
}

struct SchoolAttendanceReport: Decodable {
    let attendance: [SessionAttendanceRow]
    let manualAttendance: [ManualAttendanceRow]
    let classes: [SchoolClass]

    enum CodingKeys: String, CodingKey {
        case attendance
        case manualAttendance = "manual_attendance"
        case classes
    }
}

struct TeacherRosterResponse: Decodable {
    let classes: [SchoolClass]
    let students: [SchoolStudent]
}

struct TeacherScheduleResponse: Decodable {
    let classes: [SchoolClass]
    let schedule: [ClassScheduleEntry]
}

struct TeacherAttendanceResponse: Decodable {
    let attendance: [SessionAttendanceRow]
}

struct StudentScheduleResponse: Decodable {
    let schedule: [ClassScheduleEntry]
}

struct TeacherPerformanceRow: Identifiable, Decodable {
    var id: String { userId }
    let userId: String
    let username: String
    let fullName: String?
    let classId: String?
    let attemptsCount: Int
    let avgScore: Int
    let totalStudyMinutes: Int
    let currentStreak: Int

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case username
        case fullName = "full_name"
        case classId = "class_id"
        case attemptsCount = "attempts_count"
        case avgScore = "avg_score"
        case totalStudyMinutes = "total_study_minutes"
        case currentStreak = "current_streak"
    }
}

struct TeacherPerformanceResponse: Decodable {
    let performance: [TeacherPerformanceRow]
}

struct ManualAttendanceRecord: Decodable {
    let studentId: String
    let status: String

    enum CodingKeys: String, CodingKey {
        case studentId = "student_id"
        case status
    }
}

// MARK: - رسائل مباشرة + تنبيهات

struct ConversationSummary: Identifiable, Decodable {
    var id: String { userId }
    let userId: String
    let username: String
    let lastMessage: String?
    let lastMessageAt: String?
    let unreadCount: Int

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case username
        case lastMessage = "last_message"
        case lastMessageAt = "last_message_at"
        case unreadCount = "unread_count"
    }
}

struct DirectMessage: Identifiable, Decodable, Hashable {
    let id: String
    let senderId: String
    let recipientId: String
    let body: String
    let createdAt: String
    let readAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case senderId = "sender_id"
        case recipientId = "recipient_id"
        case body
        case createdAt = "created_at"
        case readAt = "read_at"
    }
}

struct NotificationItem: Identifiable, Decodable, Hashable {
    let id: String
    let type: String
    let title: String
    let body: String?
    let relatedClassId: String?
    let relatedRoomCode: String?
    let createdAt: String
    let readAt: String?

    enum CodingKeys: String, CodingKey {
        case id, type, title, body
        case relatedClassId = "related_class_id"
        case relatedRoomCode = "related_room_code"
        case createdAt = "created_at"
        case readAt = "read_at"
    }
}

struct NotificationsResponse: Decodable {
    let notifications: [NotificationItem]
    let unreadCount: Int

    enum CodingKeys: String, CodingKey {
        case notifications
        case unreadCount = "unread_count"
    }
}
