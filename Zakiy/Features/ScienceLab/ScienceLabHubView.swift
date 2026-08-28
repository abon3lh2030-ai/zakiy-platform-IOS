import SwiftUI

/// مدخل "مختبر العلوم" - تبويبان مطابقان لـ slTabChemistryBtn/slTabBiologyBtn
/// بالموقع بالضبط: الكيمياء والفيزياء (محاكاة ثلاثية الأبعاد حقيقية معقّدة -
/// تُعرض بمتصفح مضمّن بدل إعادة بنائها أصليًا) والأحياء (مبنية أصليًا 100%
/// بـ SwiftUI - شبكة تصنيفات ⇄ حيوانات ⇄ تفاصيل مع مساعد ذكي وتلخيص جلسة).
struct ScienceLabHubView: View {
    private enum Tab { case chemistry, biology }

    @State private var tab: Tab = .chemistry

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                Text(Loc.t("sl_tab_chemistry")).tag(Tab.chemistry)
                Text(Loc.t("sl_tab_biology")).tag(Tab.biology)
            }
            .pickerStyle(.segmented)
            .padding()

            switch tab {
            case .chemistry:
                // الكيمياء والفيزياء افتراضيًا هي التبويب الأول بالموقع نفسه -
                // ما نحتاج ننادي أي دالة تنقّل JS إضافية بعد ما تحمّل الصفحة
                EmbeddedWebScreen(target: .scienceLab)
            case .biology:
                BiologyExplorerView()
            }
        }
        .background(Color.appBackground)
        .navigationTitle(Loc.t("sl_heading"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
