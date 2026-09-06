import SwiftUI

/// شاشة تفاصيل حيوان أو جسم الإنسان - مطابقة لـ slOpenBioDetail بموقع الويب:
/// حقائق (للحيوانات بس - جسم الإنسان بلا قائمة حقائق بالمصدر الأصلي) + صورة
/// تشريح تفاعلية بنقاط ضغط.
struct BioAnimalDetailView: View {
    enum Kind: Hashable {
        case animal(String)
        case human
    }

    let kind: Kind
    let session: ScienceLabSession

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                if case .animal(let animalId) = kind, let animal = ScienceLabBioData.animals[animalId] {
                    factsList(animal)
                }

                BodyHotspotImageView(data: bodyImageData, session: session)
            }
            .padding()
        }
        .background(Color.appBackground)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .task { logOnAppear() }
    }

    @ViewBuilder
    private var header: some View {
        switch kind {
        case .animal(let animalId):
            if let animal = ScienceLabBioData.animals[animalId] {
                HStack(spacing: 12) {
                    Text(animal.icon).font(.system(size: 40))
                    Text(Loc.t(animal.nameKey)).font(.title2.weight(.bold))
                    Spacer()
                }
            }
        case .human:
            HStack(spacing: 12) {
                Text("🧍").font(.system(size: 40))
                Text(Loc.t("sl_cat_human")).font(.title2.weight(.bold))
                Spacer()
            }
        }
    }

    private func factsList(_ animal: BioAnimal) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(animal.factKeys, id: \.self) { key in
                HStack(alignment: .top, spacing: 10) {
                    Text("•").font(.headline).foregroundStyle(Color.accentColor)
                    Text(Loc.t(key)).font(.subheadline)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.appCard, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private var bodyImageData: BodyImageData {
        switch kind {
        case .animal(let animalId):
            return ScienceLabBioData.bodyImage(forAnimal: animalId)
        case .human:
            return ScienceLabBioData.bodyImages["human"]!
        }
    }

    private var title: String {
        switch kind {
        case .animal(let animalId):
            return ScienceLabBioData.animals[animalId].map { Loc.t($0.nameKey) } ?? ""
        case .human:
            return Loc.t("sl_cat_human")
        }
    }

    private func logOnAppear() {
        switch kind {
        case .animal(let animalId):
            if let animal = ScienceLabBioData.animals[animalId] { session.logAnimal(animal) }
        case .human:
            session.logHuman()
        }
    }
}
