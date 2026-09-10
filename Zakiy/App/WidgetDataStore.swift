import Foundation
import WidgetKit

/// Small shared snapshot used by the home-screen widgets. The app group keeps the widget
/// useful without making the widget perform authenticated network requests itself.
@MainActor
enum WidgetDataStore {
    static let suiteName = "group.com.zakiy.platform.shared"
    private static let defaults = UserDefaults(suiteName: suiteName) ?? .standard

    static func refresh() async {
        guard SupabaseAuthManager.shared.isAuthenticated else {
            save(streak: 0, longestStreak: 0, studyHours: 0, attempts: 0, weakTopic: nil,
                 languageCode: AppSettings.shared.languageCode)
            return
        }

        if let data = try? await APIClient.shared.performance() {
            let hours = Double(data.totalStudyMinutes) / 60
            var average = 0.0
            if !data.attempts.isEmpty {
                var scoreTotal = 0.0
                for attempt in data.attempts where attempt.total > 0 {
                    scoreTotal += Double(attempt.score) / Double(attempt.total) * 100
                }
                average = scoreTotal / Double(data.attempts.count)
            }
            save(
                streak: data.currentStreak,
                longestStreak: data.longestStreak,
                studyHours: hours,
                attempts: data.attempts.count,
                averageScore: average,
                weakTopic: data.weakTopics.first?.topic,
                languageCode: AppSettings.shared.languageCode
            )
        }
    }

    static func save(
        streak: Int,
        longestStreak: Int,
        studyHours: Double,
        attempts: Int,
        averageScore: Double = 0,
        weakTopic: String?,
        languageCode: String
    ) {
        defaults.set(streak, forKey: "streak")
        defaults.set(longestStreak, forKey: "longestStreak")
        defaults.set(studyHours, forKey: "studyHours")
        defaults.set(attempts, forKey: "attempts")
        defaults.set(averageScore, forKey: "averageScore")
        defaults.set(weakTopic, forKey: "weakTopic")
        defaults.set(languageCode, forKey: "languageCode")
        WidgetCenter.shared.reloadAllTimelines()
    }
}
