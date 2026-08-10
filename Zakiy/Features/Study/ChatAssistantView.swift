import SwiftUI

struct ChatAssistantView: View {
    let sourceText: String

    @Environment(SupabaseAuthManager.self) private var auth
    @Environment(AppSettings.self) private var settings

    @State private var messages: [ChatMessage] = []
    @State private var input = ""
    @State private var isSending = false
    @State private var interactionId: String?

    var body: some View {
        VStack(spacing: 0) {
            if messages.isEmpty {
                VStack(spacing: 10) {
                    Spacer()
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(Color.accentColor)
                    Text(Loc.t("chat_empty_title")).font(.headline)
                    Text(Loc.t("chat_empty_subtitle"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(messages) { message in
                                ChatBubble(message: message)
                                    .id(message.id)
                            }
                            if isSending {
                                HStack {
                                    ProgressView()
                                    Spacer()
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: messages.count) {
                        if let last = messages.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }
            }

            Divider()

            HStack(spacing: 10) {
                TextField(Loc.t("ask_a_question"), text: $input, axis: .vertical)
                    .lineLimit(1...4)
                    .textFieldStyle(.roundedBorder)

                Button {
                    Task { await send() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title)
                        .foregroundStyle(Color.accentColor)
                }
                .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty || isSending)
            }
            .padding()
        }
        .background(Color.appBackground)
        .navigationTitle(Loc.t("chat_with_ai"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func send() async {
        let text = input.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        input = ""
        messages.append(ChatMessage(role: .user, text: text))
        isSending = true
        do {
            let name = auth.isAuthenticated ? auth.username : nil
            let result = try await APIClient.shared.chat(
                message: text,
                context: interactionId == nil ? sourceText : nil,
                name: interactionId == nil ? name : nil,
                interactionId: interactionId,
                lang: settings.languageCode
            )
            interactionId = result.interactionId
            messages.append(ChatMessage(role: .assistant, text: result.reply))
        } catch {
            messages.append(ChatMessage(role: .assistant, text: Loc.t("error_generic")))
        }
        isSending = false
    }
}

struct ChatMessage: Identifiable {
    enum Role { case user, assistant }
    let id = UUID()
    let role: Role
    let text: String
}

private struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }
            Text(message.text)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(message.role == .user ? Color.accentColor : Color.appCard, in: RoundedRectangle(cornerRadius: 16))
                .foregroundStyle(message.role == .user ? Color.appAccentText : .primary)
            if message.role == .assistant { Spacer(minLength: 40) }
        }
    }
}
