import Foundation

/// رد الباك إند بعد مزامنة اشتراك StoreKit (POST /api/subscription/apple/verify) -
/// يخلي الاشتراك متزامن بالحساب مو محلي بالجهاز بس (لو المستخدم سجّل دخول
/// من جهاز/منصة ثانية يشوف نفس الباقة).
struct SubscriptionSyncResponse: Decodable {
    let tier: String
    let period: String
    let expiresAt: String

    enum CodingKeys: String, CodingKey {
        case tier, period
        case expiresAt = "expires_at"
    }
}
