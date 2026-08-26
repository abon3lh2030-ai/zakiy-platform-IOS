import Foundation

// MARK: - مدرستي: أدوات ذكيّ المستقلة (اختصار لموقع مدرستي الرسمي + أدوات
// ذكاء اصطناعي خاصة بذكيّ للمعلم والطالب - بدون أي تكامل بيانات فعلي مع
// مدرستي نفسها، متاحة لأي حساب مسجّل دخول بدون قيد دور). النماذج هنا تطابق
// شكل JSON اللي يرجّعه الباك إند بالضبط (backend/app.py).

/// رد أي مسار `/generate` بكل أدوات مدرستي - نص خام (محتمل ملفوف بـ ```json
/// fences) لازم يُفكّ محليًا لكائن JSON بشكل المحتوى النهائي.
struct ContentRawResponse: Decodable {
    let contentRaw: String
    enum CodingKeys: String, CodingKey { case contentRaw = "content_raw" }
}

/// يحوّل نص خام محتمل ملفوف بـ ```json fences لكائن Decodable - نفس نمط
/// معالجة رد الذكاء الاصطناعي المتبع بكل أدوات مدرستي بموقع الويب بالضبط
/// (دالة `parseAiJson` بـ 28-madrasati.js).
enum AiJSON {
    static func decode<T: Decodable>(_ raw: String, as type: T.Type) throws -> T {
        var clean = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.hasPrefix("```json") {
            clean.removeFirst("```json".count)
        } else if clean.hasPrefix("```") {
            clean.removeFirst("```".count)
        }
        if clean.hasSuffix("```") {
            clean.removeLast("```".count)
        }
        clean = clean.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = clean.data(using: .utf8) else { throw APIError.invalidResponse }
        return try JSONDecoder().decode(T.self, from: data)
    }
}

// MARK: - تحضير الدرس الذكي (معلم - بحفظ/عرض/تعديل/حذف)

struct LessonPrepContent: Codable, Hashable {
    var objectives: [String]
    var intro: String
    var steps: [String]
    var activities: [String]
    var assessment: String
    var homework: String
    var enrichment: String
}

struct LessonPrepSummary: Identifiable, Decodable, Hashable {
    let id: String
    let subject: String
    let gradeLevel: String
    let unit: String?
    let lessonTitle: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, subject, unit
        case gradeLevel = "grade_level"
        case lessonTitle = "lesson_title"
        case createdAt = "created_at"
    }
}

struct LessonPrepDetail: Decodable {
    let id: String
    let subject: String
    let gradeLevel: String
    let unit: String?
    let lessonTitle: String
    let content: LessonPrepContent

    enum CodingKeys: String, CodingKey {
        case id, subject, unit, content
        case gradeLevel = "grade_level"
        case lessonTitle = "lesson_title"
    }
}

// MARK: - نشاط إثرائي (معلم - توليد لحظي بدون حفظ)

struct EnrichmentContent: Codable, Hashable {
    var title: String
    var description: String
    var instructions: [String]
    var materialsNeeded: String?

    enum CodingKeys: String, CodingKey {
        case title, description, instructions
        case materialsNeeded = "materials_needed"
    }
}

// MARK: - محلّل نتائج الطلاب (معلم - توليد لحظي بدون حفظ)

struct ResultsAnalysisContent: Codable, Hashable {
    var overallSummary: String
    var strengths: [String]
    var weaknesses: [String]
    var atRiskStudents: [String]
    var recommendations: [String]

    enum CodingKeys: String, CodingKey {
        case strengths, weaknesses, recommendations
        case overallSummary = "overall_summary"
        case atRiskStudents = "at_risk_students"
    }
}

// MARK: - مساعد الواجب الذكي (طالب - بحفظ/عرض/حذف، بدون تعديل - ما فيه PATCH)

struct PracticeQuestion: Codable, Hashable {
    var question: String
    var answer: String
}

struct HomeworkHelpContent: Codable, Hashable {
    var explanation: String
    var workedExample: String
    var practiceQuestions: [PracticeQuestion]
    var tips: String

    enum CodingKeys: String, CodingKey {
        case explanation, tips
        case workedExample = "worked_example"
        case practiceQuestions = "practice_questions"
    }
}

struct HomeworkHelpSummary: Identifiable, Decodable, Hashable {
    let id: String
    let subject: String
    let gradeLevel: String
    let topic: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, subject, topic
        case gradeLevel = "grade_level"
        case createdAt = "created_at"
    }
}

struct HomeworkHelpDetail: Decodable {
    let id: String
    let subject: String
    let gradeLevel: String
    let topic: String
    let content: HomeworkHelpContent

    enum CodingKeys: String, CodingKey {
        case id, subject, topic, content
        case gradeLevel = "grade_level"
    }
}

// MARK: - خطة مذاكرة ذكية (طالب - بحفظ/عرض/حذف، بدون تعديل - ما فيه PATCH)

struct StudyDay: Codable, Hashable {
    var dateLabel: String
    var tasks: [String]

    enum CodingKeys: String, CodingKey {
        case tasks
        case dateLabel = "date_label"
    }
}

struct StudyPlanContent: Codable, Hashable {
    var days: [StudyDay]
    var generalTips: String

    enum CodingKeys: String, CodingKey {
        case days
        case generalTips = "general_tips"
    }
}

struct StudyPlanSummary: Identifiable, Decodable, Hashable {
    let id: String
    let subjects: String
    let examDate: String?
    let hoursPerDay: Double?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, subjects
        case examDate = "exam_date"
        case hoursPerDay = "hours_per_day"
        case createdAt = "created_at"
    }
}

struct StudyPlanDetail: Decodable {
    let id: String
    let subjects: String
    let examDate: String?
    let hoursPerDay: Double?
    let content: StudyPlanContent

    enum CodingKeys: String, CodingKey {
        case id, subjects, content
        case examDate = "exam_date"
        case hoursPerDay = "hours_per_day"
    }
}
