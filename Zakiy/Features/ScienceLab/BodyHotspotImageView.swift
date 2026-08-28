import SwiftUI

/// صورة تشريح (جسم الإنسان أو أقرب حيوان مرجعي) مع نقاط ضغط شفافة فوق مواضع
/// الأعضاء - مطابقة لـ slRenderBodyScene/slShowOrganInfo بموقع الويب: تضغط
/// نقطة فيكبّر (zoom) على مكانها بالصورة ويطلع اسم العضو ووظيفته تحت.
/// المواضع (x/y) نسبة مئوية من عرض/ارتفاع الصورة - نفس بيانات SL_BODY_IMAGES
/// بالضبط، نحوّلها لإحداثيات فعلية عبر GeometryReader.
struct BodyHotspotImageView: View {
    let data: BodyImageData
    let session: ScienceLabSession

    @State private var activeHotspot: BodyHotspot?
    @State private var selectedPart: BodyPartInfo?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(Loc.t("sl_body_hint"))
                .font(.footnote)
                .foregroundStyle(.secondary)

            GeometryReader { geo in
                ZStack {
                    imageContent

                    ForEach(data.hotspots) { hotspot in
                        Button {
                            tap(hotspot)
                        } label: {
                            Circle()
                                .fill(Color.accentColor.opacity(activeHotspot?.id == hotspot.id ? 0.95 : 0.55))
                                .overlay(Circle().stroke(.white, lineWidth: 2))
                                .frame(width: 18, height: 18)
                        }
                        .position(x: geo.size.width * hotspot.x / 100, y: geo.size.height * hotspot.y / 100)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .scaleEffect(activeHotspot != nil ? 2.1 : 1, anchor: zoomAnchorValue)
                .clipped()
            }
            .frame(height: 320)
            .background(Color.appCard, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .animation(.easeInOut(duration: 0.3), value: activeHotspot)

            if activeHotspot != nil {
                Button(Loc.t("sl_zoom_out")) {
                    withAnimation { activeHotspot = nil }
                }
                .buttonStyle(.bordered)
            }

            if let creditKey = data.creditKey {
                Text(Loc.t(creditKey))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if let selectedPart {
                VStack(alignment: .leading, spacing: 4) {
                    Text(Loc.t(selectedPart.nameKey)).font(.headline)
                    Text(Loc.t(selectedPart.descKey)).font(.subheadline).foregroundStyle(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.appCard, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    @ViewBuilder
    private var imageContent: some View {
        switch data.source {
        case .asset(let name):
            Image(name)
                .resizable()
                .scaledToFit()
        case .remote:
            AsyncImage(url: data.remoteDisplayURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFit()
                case .failure:
                    Text(Loc.t("sl_body_img_error"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .empty:
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                @unknown default:
                    EmptyView()
                }
            }
        }
    }

    private var zoomAnchorValue: UnitPoint {
        guard let activeHotspot else { return .center }
        return UnitPoint(x: activeHotspot.x / 100, y: activeHotspot.y / 100)
    }

    private func tap(_ hotspot: BodyHotspot) {
        guard let info = ScienceLabBioData.partsInfo[hotspot.part] else { return }
        withAnimation { activeHotspot = hotspot }
        selectedPart = info
        session.logPart(info)
    }
}
