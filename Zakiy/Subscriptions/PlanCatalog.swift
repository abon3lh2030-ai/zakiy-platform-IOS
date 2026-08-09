import Foundation

struct PlanDisplayInfo: Identifiable {
    var id: String { tier.nameKey }
    let tier: PlanTier
    let monthlyProductID: String
    let yearlyProductID: String
    let monthlyPriceLabel: String
    let yearlyPriceLabel: String
    let descriptionKey: String
}

enum PlanCatalog {
    static let plans: [PlanDisplayInfo] = [
        PlanDisplayInfo(tier: .plus, monthlyProductID: ProductID.plusMonthly, yearlyProductID: ProductID.plusYearly, monthlyPriceLabel: "19.99 SAR", yearlyPriceLabel: "199.99 SAR", descriptionKey: "plan_plus_description"),
        PlanDisplayInfo(tier: .pro, monthlyProductID: ProductID.proMonthly, yearlyProductID: ProductID.proYearly, monthlyPriceLabel: "39.99 SAR", yearlyPriceLabel: "399.99 SAR", descriptionKey: "plan_pro_description"),
        PlanDisplayInfo(tier: .ultimate, monthlyProductID: ProductID.ultimateMonthly, yearlyProductID: ProductID.ultimateYearly, monthlyPriceLabel: "79.99 SAR", yearlyPriceLabel: "799.99 SAR", descriptionKey: "plan_ultimate_description"),
    ]
}
