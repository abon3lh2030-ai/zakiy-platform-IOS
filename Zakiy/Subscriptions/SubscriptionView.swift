import SwiftUI

struct SubscriptionView: View {
    @State private var store = StoreManager.shared

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Text(Loc.t("current_plan")).font(.subheadline).foregroundStyle(.secondary)
                Text(Loc.t(store.currentTier.nameKey)).font(.largeTitle.bold())
            }
            .padding(.top, 20)

            ScrollView {
                VStack(spacing: 16) {
                    ForEach(PlanCatalog.plans) { plan in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(Loc.t(plan.tier.nameKey)).font(.headline)
                            Text(Loc.t(plan.descriptionKey)).font(.caption).foregroundStyle(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.appCard, in: RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding(.horizontal)
            }
            Spacer()
        }
        .background(Color.appBackground)
        .navigationTitle(Loc.t("subscription"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
