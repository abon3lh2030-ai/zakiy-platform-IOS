import SwiftUI

/// جذر مستكشف الأحياء - يستضيف NavigationStack خاص به (تصنيفات ⇄ شبكة
/// حيوانات ⇄ تفاصيل) مع شريط سفلي ثابت (مساعد ذكي + تلخيص الجلسة) يبقى
/// ظاهر طول التنقل - مطابق لفكرة اللوحة الجانبية الثابتة sl-chat-panel
/// بالموقع، بأسلوب مناسب لشاشة الجوال.
struct BiologyExplorerView: View {
    @State private var session = ScienceLabSession()
    @State private var path: [BioRoute] = []
    @State private var showChat = false
    @State private var showSummary = false

    var body: some View {
        VStack(spacing: 0) {
            NavigationStack(path: $path) {
                BioCategoryGridView(path: $path, session: session)
                    .navigationDestination(for: BioRoute.self) { route in
                        switch route {
                        case .animalGrid(let categoryId):
                            BioAnimalGridView(categoryId: categoryId, path: $path)
                        case .detail(let kind):
                            BioAnimalDetailView(kind: kind, session: session)
                        }
                    }
            }

            Divider()

            HStack(spacing: 12) {
                Button {
                    showSummary = true
                } label: {
                    Label(Loc.t("sl_show_summary"), systemImage: "doc.text.magnifyingglass")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    showChat = true
                } label: {
                    Label(Loc.t("sl_chat_heading"), systemImage: "message.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.appPrimary)
            }
            .padding(12)
            .background(Color.appBackground)
        }
        .sheet(isPresented: $showChat) {
            NavigationStack { ScienceLabChatPanel(session: session) }
        }
        .sheet(isPresented: $showSummary) {
            ScienceLabSummarySheet(session: session)
        }
    }
}
