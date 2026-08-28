import Foundation

extension BodyImageData {
    /// روابط ويكيميديا SVG ما يقدر AsyncImage (ولا UIImage عمومًا) يعرضها مباشرة
    /// - iOS ما فيه دعم أصلي لصيغة SVG بمحمّل الصور. نحوّلها لرابط الصورة
    /// المُصيَّرة PNG الجاهزة اللي ويكيميديا كومنز نفسها تولّدها تلقائيًا لكل
    /// ملف SVG بنفس نمط الرابط القياسي المعروف:
    /// commons/thumb/<حرف1>/<حرفين>/<اسم الملف>/<العرض>px-<اسم الملف>.png
    /// الصور غير الـ SVG (jpg الضفدع، وأصول الفيل/التمساح المحلية) ترجع كما
    /// هي بدون أي تحويل.
    var remoteDisplayURL: URL? {
        guard case .remote(let url) = source else { return nil }
        guard url.pathExtension.lowercased() == "svg" else { return url }
        let filename = url.lastPathComponent
        var components = url.pathComponents.filter { $0 != "/" }
        guard let commonsIndex = components.firstIndex(of: "commons") else { return url }
        components.insert("thumb", at: commonsIndex + 1)
        components.append("1000px-\(filename).png")
        guard var thumbURL = URL(string: "https://\(url.host ?? "upload.wikimedia.org")") else { return url }
        for part in components { thumbURL.appendPathComponent(part) }
        return thumbURL
    }
}
