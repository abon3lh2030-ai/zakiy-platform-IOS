import Foundation

struct TierLimits {
    let librarySave: Int?
    let soloSession: Int?
    let groupRoom: Int?
    let liveLesson: Int?
    let archiveDepth: Int?
    let performanceDepth: Int?
}

@MainActor
final class UsageLimiter {
    static let shared = UsageLimiter()
    private init() {}

    private let limits: [PlanTier: TierLimits] = [
        .free: TierLimits(librarySave: 5, soloSession: 3, groupRoom: 1, liveLesson: 0, archiveDepth: 8, performanceDepth: 5),
        .plus: TierLimits(librarySave: 20, soloSession: 5, groupRoom: 3, liveLesson: 1, archiveDepth: 15, performanceDepth: 8),
        .pro: TierLimits(librarySave: 30, soloSession: 10, groupRoom: 5, liveLesson: 3, archiveDepth: 30, performanceDepth: 15),
        .ultimate: TierLimits(librarySave: 50, soloSession: nil, groupRoom: nil, liveLesson: 8, archiveDepth: nil, performanceDepth: nil),
        .owner: TierLimits(librarySave: nil, soloSession: nil, groupRoom: nil, liveLesson: nil, archiveDepth: nil, performanceDepth: nil),
    ]

    private var tier: PlanTier { StoreManager.shared.currentTier }
    private var tierLimits: TierLimits { limits[tier] ?? limits[.free]! }

    var archiveDepth: Int? { tierLimits.archiveDepth }
    var performanceDepth: Int? { tierLimits.performanceDepth }

    func dailyLimit(for action: LimitedAction) -> Int? {
        switch action {
        case .soloSession: return tierLimits.soloSession
        case .groupRoom: return tierLimits.groupRoom
        case .liveLesson: return tierLimits.liveLesson
        case .librarySave: return tierLimits.librarySave
        }
    }

    private func todayKey(for action: LimitedAction) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "zakiy.usage.\(action.id).\(formatter.string(from: Date()))"
    }

    func canPerform(_ action: LimitedAction) -> Bool {
        guard let limit = dailyLimit(for: action) else { return true }
        let used = UserDefaults.standard.integer(forKey: todayKey(for: action))
        return used < limit
    }

    func recordUsage(_ action: LimitedAction) {
        guard dailyLimit(for: action) != nil else { return }
        let key = todayKey(for: action)
        let used = UserDefaults.standard.integer(forKey: key)
        UserDefaults.standard.set(used + 1, forKey: key)
    }
}
