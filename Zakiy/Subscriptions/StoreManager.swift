import StoreKit
import Observation

@MainActor
@Observable
final class StoreManager {
    static let shared = StoreManager()

    var products: [Product] = []
    var purchasedProductIDs: Set<String> = []
    nonisolated(unsafe) var updatesTask: Task<Void, Never>?

    private init() {
        updatesTask = listenForTransactions()
        Task { await loadProducts(); await refreshPurchasedProducts() }
    }

    var currentTier: PlanTier {
        if let email = SupabaseAuthManager.shared.email, email.caseInsensitiveCompare("abon3lh2030@gmail.com") == .orderedSame {
            return .owner
        }
        var highest: PlanTier = .free
        for id in purchasedProductIDs {
            let tier = ProductID.tier(for: id)
            if tier > highest { highest = tier }
        }
        return highest
    }

    func loadProducts() async {
        products = (try? await Product.products(for: ProductID.all)) ?? []
    }

    func purchase(_ product: Product) async throws {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            if case .verified(let transaction) = verification {
                await transaction.finish()
                await refreshPurchasedProducts()
                await syncWithBackend(productID: transaction.productID, transactionID: String(transaction.id))
            }
        default:
            break
        }
    }

    /// يبلّغ الباك إند بالاشتراك الجديد بعد نجاح الشراء فعليًا على الجهاز -
    /// لو المستخدم ضيف/مو مسجّل دخول ما نقدر نربطه بحساب، نتجاهل بصمت
    /// (StoreKit نفسه يبقى مصدر الحقيقة على هذا الجهاز رغم ذلك)
    private func syncWithBackend(productID: String, transactionID: String) async {
        guard SupabaseAuthManager.shared.isAuthenticated else { return }
        _ = try? await APIClient.shared.subscriptionAppleVerify(productID: productID, transactionID: transactionID)
    }

    func refreshPurchasedProducts() async {
        var purchased: Set<String> = []
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                purchased.insert(transaction.productID)
            }
        }
        purchasedProductIDs = purchased
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await MainActor.run {
                        Task {
                            await StoreManager.shared.refreshPurchasedProducts()
                            await StoreManager.shared.syncWithBackend(productID: transaction.productID, transactionID: String(transaction.id))
                        }
                    }
                }
            }
        }
    }
}
