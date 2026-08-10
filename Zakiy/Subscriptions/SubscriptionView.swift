import SwiftUI

struct SubscriptionView: View {
    @State private var store = StoreManager.shared
    @State private var isPurchasing = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 6) {
                    Text(Loc.t("current_plan")).font(.subheadline).foregroundStyle(.secondary)
                    Text(Loc.t(store.currentTier.nameKey)).font(.largeTitle.bold())
                }
                .padding(.top, 20)

                VStack(spacing: 16) {
                    ForEach(PlanCatalog.plans) { plan in
                        planCard(plan)
                    }
                    if let errorMessage {
                        Text(errorMessage).foregroundStyle(.red).font(.footnote)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 24)
        }
        .background(Color.appBackground)
        .navigationTitle(Loc.t("subscription"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func planCard(_ plan: PlanDisplayInfo) -> some View {
        let isCurrent = store.currentTier == plan.tier
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(Loc.t(plan.tier.nameKey)).font(.title3.bold())
                if isCurrent {
                    Text(Loc.t("current_plan"))
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.accentColor.opacity(0.2), in: Capsule())
                }
            }
            Text(Loc.t(plan.descriptionKey)).font(.footnote).foregroundStyle(.secondary)
            HStack(spacing: 10) {
                purchaseButton(productID: plan.monthlyProductID, label: "\(Loc.t("monthly_label")) - \(plan.monthlyPriceLabel)")
                purchaseButton(productID: plan.yearlyProductID, label: "\(Loc.t("yearly_label")) - \(plan.yearlyPriceLabel)")
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appCard, in: RoundedRectangle(cornerRadius: 16))
    }

    private func purchaseButton(productID: String, label: String) -> some View {
        Button(label) {
            Task { await purchase(productID: productID) }
        }
        .buttonStyle(.appPrimary)
        .controlSize(.small)
        .disabled(isPurchasing)
    }

    private func purchase(productID: String) async {
        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }
        guard let product = store.products.first(where: { $0.id == productID }) else {
            errorMessage = Loc.t("storekit_unavailable")
            return
        }
        do {
            try await store.purchase(product)
        } catch {
            errorMessage = Loc.t("error_generic")
        }
    }
}
