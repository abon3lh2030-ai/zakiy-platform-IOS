import SwiftUI

/// شبكة حيوانات تصنيف معيّن - الحقيقة السريعة (تظهر بتحويم الماوس بالموقع)
/// تظهر هنا كسطر تعريف دائم تحت اسم الحيوان بما إن اللمس ما فيه تحويم.
struct BioAnimalGridView: View {
    let categoryId: String
    @Binding var path: [BioRoute]

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    private var category: BioCategory? {
        ScienceLabBioData.categories.first { $0.id == categoryId }
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(category?.animalIds ?? [], id: \.self) { animalId in
                    if let animal = ScienceLabBioData.animals[animalId] {
                        Button {
                            path.append(.detail(.animal(animalId)))
                        } label: {
                            BioAnimalCard(animal: animal)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
        }
        .background(Color.appBackground)
        .navigationTitle(category.map { Loc.t($0.nameKey) } ?? "")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct BioAnimalCard: View {
    let animal: BioAnimal

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(animal.icon).font(.system(size: 32))
            Text(Loc.t(animal.nameKey)).font(.subheadline.weight(.semibold))
            Text(Loc.t(animal.quickFactKey))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .padding(12)
        .background(Color.appCard, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
    }
}
