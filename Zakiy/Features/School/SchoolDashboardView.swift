import SwiftUI

/// لوحة مدير المدرسة / وكيل وإداريي المدرسة - نفس الصلاحيات على المعلمين
/// والطلاب والحضور، إلا إدارة حسابات مدير/إداريي مدرسة ثانية (يتحكم فيها
/// الباك إند نفسه، الواجهة هنا مشتركة للدورين). الأقسام قائمة عناصر تُفتح
/// كل وحدة بصفحتها لحالها (بدل تبويبات مقسّمة بسطر وحد ضيق) - نفس أسلوب
/// شاشة الإعدادات، يوسّع بسهولة لو زدنا أقسام بعدين.
struct SchoolDashboardView: View {
    @State private var info: SchoolInfo?

    var body: some View {
        List {
            if let info {
                Section {
                    usageBar(info)
                }
            }

            Section {
                NavigationLink { SchoolTeachersView() } label: {
                    DashboardMenuRow(icon: "person.crop.rectangle.stack.fill", tint: .blue, title: Loc.t("tab_teachers"))
                }
                NavigationLink { SchoolAdministrationView() } label: {
                    DashboardMenuRow(icon: "person.badge.key.fill", tint: .brown, title: Loc.t("admin_staff_heading"))
                }
                NavigationLink { SchoolStudentsView() } label: {
                    DashboardMenuRow(icon: "person.3.fill", tint: .teal, title: Loc.t("tab_students"))
                }
                NavigationLink { SchoolClassesView() } label: {
                    DashboardMenuRow(icon: "tag.fill", tint: .orange, title: Loc.t("tab_classes"))
                }
                NavigationLink { SchoolBulkAddView() } label: {
                    DashboardMenuRow(icon: "person.badge.plus.fill", tint: .green, title: Loc.t("tab_bulk_students"))
                }
                NavigationLink { SchoolAttendanceView() } label: {
                    DashboardMenuRow(icon: "checklist", tint: .purple, title: Loc.t("tab_attendance"))
                }
                // مكتبة مدير/إداري المدرسة الشخصية - نفس شاشة مكتبة الطلاب
                // بالضبط، بس مدموجة هنا لأن حساب مؤسسي ما يوصل MainTabView إطلاقًا
                NavigationLink { LibraryListView() } label: {
                    DashboardMenuRow(icon: "books.vertical.fill", tint: .indigo, title: Loc.t("tab_library"))
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .navigationTitle(Loc.t("school_dash_heading"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { RoleDashboardToolbar() }
        .task { info = try? await APIClient.shared.schoolInfo() }
    }

    private func usageBar(_ info: SchoolInfo) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ProgressView(value: info.maxAccounts > 0 ? Double(info.accountsUsed) / Double(info.maxAccounts) : 0)
            Text(String(format: Loc.t("school_usage_text"), info.accountsUsed, info.maxAccounts))
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

/// صندوق بيانات دخول تُعرض مرة وحدة (كلمة سر عشوائية جديدة) - نفس التنسيق
/// مستخدم بلوحتي الأدمن والمدرسة.
func credentialResultBox(_ creds: GeneratedCredentials, title: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
        Text(title).font(.footnote.bold())
        Text(creds.email).font(.footnote)
        Text(creds.password).font(.footnote.monospaced())
    }
    .padding(8)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
}

/// نفس الصندوق، لكن لنتيجة إعادة تعيين كلمة سر حساب موجود (معلم أو طالب) -
/// "identifier" مو بالضرورة بريد فعلي (حساب الطالب يتعرّف باسم مستخدم بس)
func credentialResultBox(_ creds: AccountResetCredentials, title: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
        Text(title).font(.footnote.bold())
        Text(creds.identifier).font(.footnote)
        Text(creds.password).font(.footnote.monospaced())
    }
    .padding(8)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
}
