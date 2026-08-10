import SwiftUI

struct ConversationThreadView: View {
    let userId: String
    let username: String

    @Environment(SupabaseAuthManager.self) private var auth
    @State private var messages: [DirectMessage] = []
    @State private var input = ""

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(messages) { message in
                            bubble(message).id(message.id)
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
            HStack {
                TextField(Loc.t("type_a_message"), text: $input)
                    .textFieldStyle(.roundedBorder)
                Button {
                    Task { await send() }
                } label: {
                    Image(systemName: "paperplane.fill")
                }
                .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
        }
        .background(Color.appBackground)
        .navigationTitle(username)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func bubble(_ message: DirectMessage) -> some View {
        let isMine = message.senderId == auth.userId
        return HStack {
            if isMine { Spacer(minLength: 48) }
            Text(message.body)
                .font(.subheadline)
                .foregroundStyle(isMine ? Color.appAccentText : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(isMine ? Color.accentColor : Color.appCard, in: RoundedRectangle(cornerRadius: 16))
            if !isMine { Spacer(minLength: 48) }
        }
    }

    private func load() async {
        messages = (try? await APIClient.shared.messageThread(otherUserId: userId)) ?? []
        await NotificationSocketManager.shared.refreshUnreadCount()
    }

    private func send() async {
        let text = input.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        input = ""
        try? await APIClient.shared.sendMessage(recipientId: userId, body: text)
        await load()
    }
}
