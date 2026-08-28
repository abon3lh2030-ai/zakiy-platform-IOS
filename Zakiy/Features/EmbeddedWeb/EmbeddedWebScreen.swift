import SwiftUI
import WebKit

/// شاشة عامة قابلة لإعادة الاستخدام - تعرض موقع ذكيّ الرسمي (zakiy.tech) داخل
/// WKWebView مضمّن، مع تمرير جلسة تسجيل الدخول تلقائيًا (بدون ما يضطر
/// المستخدم يسجّل دخول مرة ثانية داخل المتصفح المضمّن) والقفز مباشرة لشاشة
/// الهدف عبر دوال JS العامة الموجودة أصلًا بالموقع - تُستخدم لمعمل الروبوتات
/// وتبويب الكيمياء والفيزياء بمختبر العلوم (الاثنان معقّدان جدًا - محاكاة
/// ثلاثية الأبعاد حقيقية بـ three.js ومحاكي دارات Arduino كامل - إعادة بنائهم
/// أصليًا تاخذ أسابيع وتطلع أضعف من النسخة الحية، فنعرض نفس النسخة الحية).
enum EmbeddedWebTarget {
    case roboticsLab
    case scienceLab

    /// دالة JS عامة موجودة أصلًا بـ website/src/js/04-profile.js تنقّل مباشرة
    /// لشاشة الهدف بعد ما تحمّل الصفحة وتتأكد الجلسة - الكيمياء هي التبويب
    /// الافتراضي بمختبر العلوم فما تحتاج نداء إضافي بعد showScienceLabScreen
    var jsEntryCall: String {
        switch self {
        case .roboticsLab: return "if (typeof showRoboticsLabScreen === 'function') { showRoboticsLabScreen(); }"
        case .scienceLab: return "if (typeof showScienceLabScreen === 'function') { showScienceLabScreen(); }"
        }
    }
}

struct EmbeddedWebScreen: View {
    let target: EmbeddedWebTarget

    @State private var isLoading = true
    @State private var loadError: String?
    @State private var reloadToken = UUID()

    var body: some View {
        ZStack {
            EmbeddedWebViewRepresentable(target: target, reloadToken: reloadToken, isLoading: $isLoading, loadError: $loadError)

            if isLoading {
                ProgressView(Loc.t("loading"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.appBackground)
            }

            if let loadError {
                VStack(spacing: 14) {
                    Image(systemName: "wifi.exclamationmark").font(.system(size: 34)).foregroundStyle(.secondary)
                    Text(loadError).multilineTextAlignment(.center).foregroundStyle(.secondary)
                    Button(Loc.t("retry")) {
                        self.loadError = nil
                        isLoading = true
                        reloadToken = UUID()
                    }
                    .buttonStyle(.appPrimary)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.appBackground)
            }
        }
    }
}

private struct EmbeddedWebViewRepresentable: UIViewRepresentable {
    let target: EmbeddedWebTarget
    let reloadToken: UUID
    @Binding var isLoading: Bool
    @Binding var loadError: String?

    func makeCoordinator() -> Coordinator {
        Coordinator(target: target, isLoading: $isLoading, loadError: $loadError)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let controller = WKUserContentController()
        if let script = EmbeddedWebAuthBridge.injectionScript() {
            controller.addUserScript(WKUserScript(source: script, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        }
        config.userContentController = controller

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: EmbeddedWebAuthBridge.baseURL))
        context.coordinator.lastLoadedToken = reloadToken
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.lastLoadedToken != reloadToken else { return }
        context.coordinator.lastLoadedToken = reloadToken
        webView.load(URLRequest(url: EmbeddedWebAuthBridge.baseURL))
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        let target: EmbeddedWebTarget
        var isLoading: Binding<Bool>
        var loadError: Binding<String?>
        var lastLoadedToken: UUID?

        init(target: EmbeddedWebTarget, isLoading: Binding<Bool>, loadError: Binding<String?>) {
            self.target = target
            self.isLoading = isLoading
            self.loadError = loadError
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoading.wrappedValue = false
            loadError.wrappedValue = nil
            webView.evaluateJavaScript(target.jsEntryCall, completionHandler: nil)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            isLoading.wrappedValue = false
            loadError.wrappedValue = Loc.t("embedded_web_load_error")
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            isLoading.wrappedValue = false
            loadError.wrappedValue = Loc.t("embedded_web_load_error")
        }
    }
}
