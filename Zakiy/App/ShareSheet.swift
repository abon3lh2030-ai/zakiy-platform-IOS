import SwiftUI
import UIKit

/// غلاف بسيط لـ UIActivityViewController - يستخدم لتصدير/مشاركة بيانات
/// الطلاب المولّدة بالجملة (CSV) بدل أي مكتبة تصدير خارجية.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

enum CSVExporter {
    /// يبني ملف CSV مؤقت من صفوف الطلاب المولّدين ويرجّع رابطه - يُمرّر
    /// مباشرة لـ `ShareSheet` عشان المستخدم يحفظه/يشاركه بأي طريقة يبيها.
    static func makeStudentsCSV(_ students: [GeneratedStudent]) -> URL? {
        var csv = "\(Loc.t("th_name")),\(Loc.t("th_username")),\(Loc.t("th_password"))\r\n"
        for s in students {
            csv += "\"\(s.name.replacingOccurrences(of: "\"", with: "\"\""))\",\"\(s.username)\",\"\(s.password)\"\r\n"
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("zakiy-students-\(UUID().uuidString).csv")
        do {
            try csv.data(using: .utf8)?.write(to: url)
            return url
        } catch {
            return nil
        }
    }
}
