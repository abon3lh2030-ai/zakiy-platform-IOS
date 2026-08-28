import Foundation
import Observation

/// حالة جلسة استكشاف الأحياء - مشتركة بين شاشات التصنيفات/الشبكة/التفاصيل
/// عبر NavigationStack وحدة (نفس فكرة SL.sessionLog/SL.chatInteractionId
/// بموقع الويب): سجل نصي لكل تفاعل (تصنيف اختير، حيوان استُكشف، عضو اتُّضغط،
/// سؤال اتُّسأل) يُرسل كامل لنقطة تلخيص الجلسة بالذكاء الاصطناعي، ومعرّف
/// المحادثة المستمر اللي يخلّي المساعد الذكي يفتكر سياق الأسئلة السابقة.
@MainActor
@Observable
final class ScienceLabSession {
    private(set) var log: [String] = []
    var chatInteractionId: String?
    var chatMessages: [ScienceLabChatMessage] = []

    /// اسم آخر حيوان/شاشة يستكشفها الطالب - يُرسل كسياق لكل رسالة شات جديدة
    var currentContextName: String?

    func logCategory(_ category: BioCategory) {
        log.append("\(Loc.t("sl_log_category_prefix")): \(Loc.t(category.nameKey))")
    }

    func logAnimal(_ animal: BioAnimal) {
        currentContextName = Loc.t(animal.nameKey)
        log.append("\(Loc.t("sl_log_animal_prefix")): \(Loc.t(animal.nameKey))")
    }

    func logHuman() {
        currentContextName = Loc.t("sl_cat_human")
    }

    func logPart(_ part: BodyPartInfo) {
        log.append("\(Loc.t("sl_log_part_prefix")): \(Loc.t(part.nameKey))")
    }

    func logQuestion(_ text: String) {
        log.append("\(Loc.t("sl_log_question_prefix")): \(text)")
    }
}

struct ScienceLabChatMessage: Identifiable, Hashable {
    let id = UUID()
    let role: String // "user" أو "ai"
    let text: String
    var isError = false
}
