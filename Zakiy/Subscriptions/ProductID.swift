import Foundation

enum PlanTier: Int, Comparable {
    case free = 0, plus, pro, ultimate, owner

    static func < (lhs: PlanTier, rhs: PlanTier) -> Bool { lhs.rawValue < rhs.rawValue }

    var nameKey: String {
        switch self {
        case .free: return "plan_free"
        case .plus: return "plan_plus"
        case .pro: return "plan_pro"
        case .ultimate: return "plan_ultimate"
        case .owner: return "plan_owner"
        }
    }
}

enum ProductID {
    static let plusMonthly = "com.zakiy.plus.monthly"
    static let plusYearly = "com.zakiy.plus.yearly"
    static let proMonthly = "com.zakiy.pro.monthly"
    static let proYearly = "com.zakiy.pro.yearly"
    static let ultimateMonthly = "com.zakiy.ultimate.monthly"
    static let ultimateYearly = "com.zakiy.ultimate.yearly"

    static let all: [String] = [plusMonthly, plusYearly, proMonthly, proYearly, ultimateMonthly, ultimateYearly]

    static func tier(for productID: String) -> PlanTier {
        switch productID {
        case plusMonthly, plusYearly: return .plus
        case proMonthly, proYearly: return .pro
        case ultimateMonthly, ultimateYearly: return .ultimate
        default: return .free
        }
    }
}

enum LimitedAction: Identifiable {
    case soloSession, groupRoom, liveLesson, librarySave

    var id: String {
        switch self {
        case .soloSession: return "soloSession"
        case .groupRoom: return "groupRoom"
        case .liveLesson: return "liveLesson"
        case .librarySave: return "librarySave"
        }
    }
}
