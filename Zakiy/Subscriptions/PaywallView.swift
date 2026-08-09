import SwiftUI
import StoreKit

struct PaywallView: View {
    let triggeredBy: LimitedAction?

    @Environment(\.dismiss) private var dismiss
    @State private var store = StoreManager.shared
    @State private var isPurchasing = false
    @State private var errorMessage: String?

    init(triggeredBy: LimitedAction? = nil) {
        self.triggeredBy = triggeredBy
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(PlanCatalog.plans) { plan in
                        planCard(plan)
                    }
                    if let errorMessage {
                        Text(errorMessage).foregroundStyle(.red).font(.footnote)
                    }
                }
                .padding()
            }
            .background(Color.appBackground)
            .navigationTitle(Loc.t("subscription"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(Loc.t("cancel")) { dismiss() }
                }
            }
        }
    }

    private func planCard(_ plan: PlanDisplayInfo) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(Loc.t(plan.tier.nameKey)).font(.title3.bold())
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
            dismiss()
        } catch {
            errorMessage = Loc.t("error_generic")
        }
    }
}
