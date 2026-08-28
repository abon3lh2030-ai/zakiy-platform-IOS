import SwiftUI

/// معمل الروبوتات - محاكي دارات (سحب أسلاك على لوحة تجارب) + محوّل كود
/// Arduino + محرر بلوكات كامل، معقّد جدًا وموجود جاهز ومُتقن بالموقع - يُعرض
/// بمتصفح مضمّن بدل إعادة بنائه أصليًا (راجع تعليق EmbeddedWebScreen).
struct RoboticsLabView: View {
    var body: some View {
        EmbeddedWebScreen(target: .roboticsLab)
            .navigationTitle(Loc.t("nav_robotics_lab"))
            .navigationBarTitleDisplayMode(.inline)
    }
}
