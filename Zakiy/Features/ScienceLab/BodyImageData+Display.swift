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
        // ويكيميديا لم تعد تقبل كل مقاسات روابط /thumb اليدوية (مثل 1000px)
        // وتعيد 400. Special:Redirect يختار تلقائيًا مقاس PNG صالحًا ويتابع
        // أي تغيير في مسار/نسخة الملف، لذلك يعمل مع URLSession وAsyncImage.
        var redirect = URL(string: "https://commons.wikimedia.org/wiki/Special:Redirect/file")!
        redirect.appendPathComponent(url.lastPathComponent)
        var components = URLComponents(url: redirect, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "width", value: "1280")]
        return components?.url
    }

    /// نسبة أبعاد الصورة الأصلية المستخدمة في الموقع. تثبيت مساحة العرض على
    /// هذه النسبة يجعل إحداثيات النقاط المئوية تطابق الصورة نفسها بلا فراغات
    /// علوية/جانبية ناتجة من scaledToFit.
    var displayAspectRatio: CGFloat {
        switch id {
        case "human": return 1280 / 1139
        case "dog": return 1280 / 807
        case "elephant": return 1264 / 844
        case "crocodile": return 957 / 463
        case "cat": return 1280 / 532
        case "reptile": return 1
        case "fish": return 1280 / 668
        case "whale": return 1280 / 531
        case "turtle": return 1280 / 557
        case "frog": return 2115 / 3276
        case "bird": return 1280 / 979
        default: return 4 / 3
        }
    }
}
