import Foundation
import Supabase

/// يحقن جلسة Supabase الحالية (نفس التوكن اللي التطبيق مسجّل دخول فيه أصلًا
/// عبر SupabaseAuthManager) داخل localStorage الخاص بموقع zakiy.tech، بنفس
/// المفتاح اللي عميل supabase-js بالموقع يخزّن جلسته تحته افتراضيًا
/// (sb-<project-ref>-auth-token). لازم يشتغل قبل ما تحمّل صفحة الموقع (نحقنه
/// كـ WKUserScript بمرحلة atDocumentStart) عشان GoTrueClient بالموقع يلقى
/// الجلسة جاهزة وقت تهيئته ويتخطى شاشة تسجيل الدخول بالكامل - نفس حساب
/// المستخدم بالضبط، بدون أي دخول ثاني.
///
/// project-ref مستخرج من APIConfig.supabaseURL (نفس مشروع Supabase بالضبط
/// المستخدم بالموقع - تأكدنا من هذا بمقارنة SUPABASE_URL بملف
/// website/src/js/00-globals.js).
enum EmbeddedWebAuthBridge {
    static let baseURL = URL(string: "https://zakiy.tech")!

    private static var projectRef: String {
        APIConfig.supabaseURL.host?.components(separatedBy: ".").first ?? ""
    }

    static var storageKey: String { "sb-\(projectRef)-auth-token" }

    /// يبني نص جافاسكربت يحقن الجلسة بـ localStorage - يرجّع nil لو ما فيه
    /// جلسة حالية (نظريًا ما ينفتح هذا الشاشة أصلًا بدون تسجيل دخول، لكن
    /// احتياطًا).
    @MainActor
    static func injectionScript() -> String? {
        guard let session = SupabaseAuthManager.shared.session else { return nil }
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(session),
              let jsonText = String(data: data, encoding: .utf8) else { return nil }
        return """
        (function () {
          try {
            localStorage.setItem('\(storageKey)', JSON.stringify(\(jsonText)));
          } catch (e) {}
        })();
        """
    }
}
