import SwiftUI

/// خطوة التنقل داخل مستكشف الأحياء - شبكة الحيوانات لتصنيف معيّن، أو شاشة
/// تفاصيل حيوان/جسم الإنسان. مطابقة لتدفق slOpenBioCategory/slOpenBioDetail
/// بموقع الويب، بس عبر NavigationStack أصيل بدل إظهار/إخفاء ألواح.
enum BioRoute: Hashable {
    case animalGrid(categoryId: String)
    case detail(BioAnimalDetailView.Kind)
}

struct BioCategoryGridView: View {
    @Binding var path: [BioRoute]
    let session: ScienceLabSession

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(Loc.t("sl_bio_pick_category"))
                    .font(.headline)

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(ScienceLabBioData.categories) { category in
                        Button {
                            open(category)
                        } label: {
                            BioCategoryCard(category: category)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
        }
        .background(Color.appBackground)
        .navigationTitle(Loc.t("sl_tab_biology"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func open(_ category: BioCategory) {
        session.logCategory(category)
        if category.id == "human" {
            path.append(.detail(.human))
        } else {
            path.append(.animalGrid(categoryId: category.id))
        }
    }
}

private struct BioCategoryCard: View {
    let category: BioCategory

    var body: some View {
        VStack(spacing: 10) {
            Text(category.icon).font(.system(size: 36))
            Text(Loc.t(category.nameKey))
                .font(.subheadline.weight(.medium))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
        .padding(12)
        .background(Color.appCard, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
    }
}
