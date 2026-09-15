import Foundation
import UIKit
import WebKit

/// صفحة المختبر المضمّنة تستخدم الصور نفسها المرفقة بمستكشف الأحياء الأصلي.
/// لا تحتاج صور الحيوانات إلى اتصال بويكيميديا أو دعم SVG وقت التشغيل.
final class BiologyImageSchemeHandler: NSObject, WKURLSchemeHandler {
    static let scheme = "zakiy-biology"
    static let injectionScript = """
    (function () {
      if (typeof SL_BODY_IMAGES === 'undefined') return;
      Object.keys(SL_BODY_IMAGES).forEach(function (key) {
        SL_BODY_IMAGES[key].url = 'zakiy-biology://body/' + encodeURIComponent(key);
      });
    })();
    """

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url,
              url.host == "body",
              let body = ScienceLabBioData.bodyImages[url.lastPathComponent],
              case .asset(let name) = body.source,
              let image = UIImage(named: name), let bytes = image.pngData() else {
            urlSchemeTask.didFailWithError(NSError(domain: "BiologyImage", code: 404))
            return
        }
        urlSchemeTask.didReceive(URLResponse(url: url, mimeType: "image/png", expectedContentLength: bytes.count, textEncodingName: nil))
        urlSchemeTask.didReceive(bytes)
        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}
}
