import SwiftUI

struct ChatAssistantView: View {
    let sourceText: String

    @State private var messages: [ChatMessage] = []
    @State private var input = ""
    @State private var isSending = false

    var body: some View {
        VStack(spacing: 0) {
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
                        .foregroundStyle(.accentColor)
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
            let history: [[String: String]] = messages.dropLast().map {
                ["role": $0.role == .user ? "user" : "assistant", "content": $0.text]
            }
            let reply = try await APIClient.shared.chat(text: sourceText, question: text, history: history)
            messages.append(ChatMessage(role: .assistant, text: reply))
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
