import SwiftUI

/// Shared bubble row for room text chat (used by both the quiz-room and classroom chat sheets):
/// my own messages align trailing in an accent bubble, everyone else's align leading in a card
/// bubble with their name shown above.
struct RoomChatBubbleRow: View {
    let message: RoomChatMessage
    let isMine: Bool

    var body: some View {
        HStack {
            if isMine { Spacer(minLength: 48) }

            VStack(alignment: isMine ? .trailing : .leading, spacing: 3) {
                if !isMine {
                    Text(message.name)
                        .font(.caption.bold())
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 4)
                }
                Text(message.message)
                    .font(.subheadline)
                    .foregroundStyle(isMine ? Color.appAccentText : .primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(isMine ? Color.accentColor : Color.appCard, in: RoundedRectangle(cornerRadius: 16))
            }

            if !isMine { Spacer(minLength: 48) }
        }
    }
}

/// Full scrollable message list + composer, shared by the quiz-room and classroom chat sheets.
struct RoomChatBody: View {
    @Bindable var socket: RoomSocketManager
    @State private var input = ""

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(socket.chatMessages) { message in
                            RoomChatBubbleRow(message: message, isMine: message.name == socket.myName)
                                .id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: socket.chatMessages.count) {
                    if let last = socket.chatMessages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }
            Divider()
            HStack {
                TextField(Loc.t("type_a_message"), text: $input)
                    .textFieldStyle(.roundedBorder)
                Button {
                    let text = input.trimmingCharacters(in: .whitespaces)
                    guard !text.isEmpty else { return }
                    socket.sendChatMessage(text)
                    input = ""
                } label: {
                    Image(systemName: "paperplane.fill")
                }
                .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
        }
        .background(Color.appBackground)
    }
}
