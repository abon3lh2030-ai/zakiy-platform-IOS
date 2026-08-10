import SwiftUI

struct SubscriptionView: View {
    @State private var store = StoreManager.shared
    @State private var isPurchasing = false
    @State private var errorMessage: String?
    @State private var billingPeriod: BillingPeriod = .monthly

    private enum BillingPeriod { case monthly, yearly }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                HStack {
                    Text(Loc.t("current_plan")).foregroundStyle(.secondary)
                    Spacer()
                    Text(Loc.t(store.currentTier.nameKey)).font(.headline)
                }
                .padding(.horizontal)
                .padding(.top, 12)

                Picker(Loc.t("billing_period"), selection: $billingPeriod) {
                    Text(Loc.t("monthly_label")).tag(BillingPeriod.monthly)
                    Text(Loc.t("yearly_label")).tag(BillingPeriod.yearly)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                VStack(spacing: 16) {
                    ForEach(PlanCatalog.plans) { plan in
                        planCard(plan)
                    }
                    if let errorMessage {
                        Text(errorMessage).foregroundStyle(.red).font(.footnote)
                    }
                }
                .padding(.horizontal)

                Button(Loc.t("restore_purchases")) {
                    Task { await store.refreshPurchasedProducts() }
                }
                .font(.footnote)
                .foregroundStyle(Color.accentColor)
            }
            .padding(.bottom, 24)
        }
        .background(Color.appBackground)
        .navigationTitle(Loc.t("subscription"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func planCard(_ plan: PlanDisplayInfo) -> some View {
        let isCurrent = store.currentTier == plan.tier
        let productID = billingPeriod == .monthly ? plan.monthlyProductID : plan.yearlyProductID
        let priceLabel = billingPeriod == .monthly ? plan.monthlyPriceLabel : plan.yearlyPriceLabel

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(Loc.t(plan.tier.nameKey)).font(.title3.bold())
                Spacer()
                Text(priceLabel).font(.title3.bold())
            }
            Text(Loc.t(plan.descriptionKey)).font(.footnote).foregroundStyle(.secondary)

            if isCurrent {
                Text(Loc.t("current_plan_badge"))
                    .font(.caption.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundStyle(.secondary)
            } else {
                Button {
                    Task { await purchase(productID: productID) }
                } label: {
                    if isPurchasing {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text(Loc.t("subscribe_button")).frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.appPrimary)
                .disabled(isPurchasing)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appCard, in: RoundedRectangle(cornerRadius: 16))
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
