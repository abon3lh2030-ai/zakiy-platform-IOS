import SwiftUI

struct StudyHubView: View {
    let sourceText: String

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                NavigationLink {
                    ChatAssistantView(sourceText: sourceText)
                } label: {
                    StudyOptionCard(icon: "bubble.left.and.bubble.right.fill", title: Loc.t("chat_with_ai"), subtitle: Loc.t("chat_with_ai_subtitle"))
                }
                .buttonStyle(.plain)

                NavigationLink {
                    QuizView(sourceText: sourceText)
                } label: {
                    StudyOptionCard(icon: "questionmark.circle.fill", title: Loc.t("generate_quiz"), subtitle: Loc.t("generate_quiz_subtitle"))
                }
                .buttonStyle(.plain)
            }
            .padding()
        }
        .background(Color.appBackground)
        .navigationTitle(Loc.t("study"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct StudyOptionCard: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(Color.appAccentText)
                .frame(width: 48, height: 48)
                .background(Color.accentColor.gradient, in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.forward").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(Color.appCard, in: RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
    }
}
