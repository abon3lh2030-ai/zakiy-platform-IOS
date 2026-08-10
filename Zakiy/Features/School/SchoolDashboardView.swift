import SwiftUI

/// لوحة مدير المدرسة / وكيل وإداريي المدرسة - نفس الصلاحيات على المعلمين
/// والطلاب والحضور، إلا إدارة حسابات مدير/إداريي مدرسة ثانية (يتحكم فيها
/// الباك إند نفسه، الواجهة هنا مشتركة للدورين).
struct SchoolDashboardView: View {
    private enum Tab: String, CaseIterable, Identifiable {
        case teachers, classes, bulk, attendance
        var id: String { rawValue }
        var titleKey: String {
            switch self {
            case .teachers: "tab_teachers"
            case .classes: "tab_classes"
            case .bulk: "tab_bulk_students"
            case .attendance: "tab_attendance"
            }
        }
    }

    @State private var tab: Tab = .teachers
    @State private var info: SchoolInfo?

    var body: some View {
        VStack(spacing: 0) {
            if let info {
                usageBar(info)
            }
            Picker("", selection: $tab) {
                ForEach(Tab.allCases) { t in
                    Text(Loc.t(t.titleKey)).tag(t)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)

            Group {
                switch tab {
                case .teachers: SchoolTeachersView()
                case .classes: SchoolClassesView()
                case .bulk: SchoolBulkAddView()
                case .attendance: SchoolAttendanceView()
                }
            }
        }
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
        .padding(.horizontal)
        .padding(.top, 8)
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
