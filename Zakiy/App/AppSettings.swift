import SwiftUI
import Observation

enum AppearanceMode: String, CaseIterable {
    case system, light, dark

    var labelKey: String {
        switch self {
        case .system: return "appearance_system"
        case .light: return "appearance_light"
        case .dark: return "appearance_dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

@MainActor
@Observable
final class AppSettings {
    static let shared = AppSettings()

    /// Mirrors `languageCode` outside actor isolation so `Loc.t(_:)` can read it from any
    /// context (including `nonisolated` protocol requirements like `LocalizedError.errorDescription`).
    nonisolated(unsafe) static var currentLanguageCode = "ar"

    var languageCode: String {
        didSet {
            UserDefaults.standard.set(languageCode, forKey: "zakiy.languageCode")
            Self.currentLanguageCode = languageCode
        }
    }
    var appearanceMode: AppearanceMode {
        didSet { UserDefaults.standard.set(appearanceMode.rawValue, forKey: "zakiy.appearanceMode") }
    }
    var isGuest: Bool {
        didSet { UserDefaults.standard.set(isGuest, forKey: "zakiy.isGuest") }
    }
    var guestName: String {
        didSet { UserDefaults.standard.set(guestName, forKey: "zakiy.guestName") }
    }

    var locale: Locale { Locale(identifier: languageCode) }
    var layoutDirection: LayoutDirection { languageCode == "ar" ? .rightToLeft : .leftToRight }

    private init() {
        // Only fall back to the device's own language on first launch (no saved preference
        // yet) — once the user has explicitly picked ar/en from Settings, that choice always
        // wins over the phone's language.
        let savedLanguage = UserDefaults.standard.string(forKey: "zakiy.languageCode") ?? Self.detectDeviceLanguageCode()
        languageCode = savedLanguage
        Self.currentLanguageCode = savedLanguage
        let savedAppearance = UserDefaults.standard.string(forKey: "zakiy.appearanceMode") ?? AppearanceMode.system.rawValue
        appearanceMode = AppearanceMode(rawValue: savedAppearance) ?? .system
        isGuest = UserDefaults.standard.bool(forKey: "zakiy.isGuest")
        guestName = UserDefaults.standard.string(forKey: "zakiy.guestName") ?? ""
    }

    /// Arabic if the phone's preferred language is Arabic (any region variant, e.g. "ar-SA"),
    /// English for every other language — we only ship ar/en content, so anything else falls
    /// back to English rather than silently defaulting to Arabic regardless of device language.
    private static func detectDeviceLanguageCode() -> String {
        let preferred = Locale.preferredLanguages.first ?? "en"
        return preferred.hasPrefix("ar") ? "ar" : "en"
    }
}
