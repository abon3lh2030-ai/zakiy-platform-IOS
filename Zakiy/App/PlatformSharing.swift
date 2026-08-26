import SwiftUI

/// اختيار منصة واجب/اختبار جديد (ذكّي/مدرستي) - يظهر بشاشات الإنشاء
/// (AssignmentCreateSheet/QuizCreateView) بس. لو اختار المعلم "مدرستي" نعرض
/// حقل رابط اختياري + زر فتح سريع لصفحة تسجيل الدخول الرسمية (ما فيه رابط
/// عام موحّد لكل واجب/اختبار بمدرستي - هذا اختصار بس لو المعلم لسا ما سواه
/// هناك ووصل هذي النقطة أول مرة).
struct PlatformPickerField: View {
    @Binding var platform: String
    @Binding var externalLink: String
    @State private var showSignIn = false

    var body: some View {
        Picker(Loc.t("platform_label"), selection: $platform) {
            Text(Loc.t("platform_zakiy")).tag("zakiy")
            Text(Loc.t("platform_madrasati")).tag("madrasati")
        }
        .pickerStyle(.segmented)

        if platform == "madrasati" {
            TextField(Loc.t("external_link_placeholder"), text: $externalLink)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            Button(Loc.t("btn_open_madrasati_quick")) { showSignIn = true }
                .font(.caption)
                .sheet(isPresented: $showSignIn) {
                    SafariView(url: URL(string: "https://schools.madrasati.sa/Auth/SignIn")!)
                }
        }
    }
}

/// محرر رابط مدرستي بشاشة تفصيل واجب/اختبار موجود أصلًا - يقدر المعلم يضيف
/// أو يعدّل الرابط بأي وقت (حتى بعد نشر الاختبار، الباك إند يسمح بهذا الحقل
/// دايمًا عكس بقية الحقول اللي تتقفل بعد النشر).
struct PlatformLinkEditor: View {
    let currentLink: String?
    var onSave: (String) async -> Void

    @State private var text: String
    @State private var isSaving = false
    @State private var showSignIn = false

    init(currentLink: String?, onSave: @escaping (String) async -> Void) {
        self.currentLink = currentLink
        self.onSave = onSave
        _text = State(initialValue: currentLink ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(Loc.t("platform_madrasati_badge"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.brown)

            HStack {
                TextField(Loc.t("external_link_placeholder"), text: $text)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button {
                    Task {
                        isSaving = true
                        await onSave(text)
                        isSaving = false
                    }
                } label: {
                    if isSaving { ProgressView() } else { Text(Loc.t("save")) }
                }
                .disabled(isSaving)
            }

            Button(Loc.t("btn_open_madrasati_quick")) { showSignIn = true }
                .font(.caption)
                .sheet(isPresented: $showSignIn) {
                    SafariView(url: URL(string: "https://schools.madrasati.sa/Auth/SignIn")!)
                }
        }
        .padding(12)
        .background(Color.appCard, in: RoundedRectangle(cornerRadius: 10))
    }
}

/// زر "افتح على مدرستي" الوحيد بمنظور الطالب لواجب/اختبار منصته مدرستي -
/// يفتح رابط المعلم لو موجود، وإلا صفحة تسجيل الدخول الرسمية مع ملاحظة إن
/// المعلم لسا ما حط رابط مخصص.
struct OpenOnMadrasatiView: View {
    let externalLink: String?
    @State private var showLink = false

    private var hasSpecificLink: Bool {
        !(externalLink?.isEmpty ?? true)
    }

    private var linkURL: URL {
        if let externalLink, let url = URL(string: externalLink) { return url }
        return URL(string: "https://schools.madrasati.sa/Auth/SignIn")!
    }

    var body: some View {
        VStack(spacing: 10) {
            Button {
                showLink = true
            } label: {
                Text(Loc.t("btn_open_on_madrasati")).frame(maxWidth: .infinity)
            }
            .buttonStyle(.appPrimary)

            if !hasSpecificLink {
                Text(Loc.t("madrasati_no_link_note"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .sheet(isPresented: $showLink) {
            SafariView(url: linkURL)
        }
    }
}
