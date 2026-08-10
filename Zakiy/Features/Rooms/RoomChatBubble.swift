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
                Text(message.name)
                    .font(.caption.bold())
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 4)
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
    @State private var isCurrentlyTyping = false
    @State private var stopTypingTask: Task<Void, Never>?

    private var othersTyping: [String] {
        Array(socket.typingNames.subtracting([socket.myName]))
    }

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

            if !othersTyping.isEmpty {
                HStack {
                    Text(othersTyping.count == 1 ? String(format: Loc.t("is_typing"), othersTyping[0]) : Loc.t("are_typing"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.bottom, 4)
            }

            Divider()
            HStack {
                TextField(Loc.t("type_a_message"), text: $input)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: input) { _, newValue in
                        handleInputChange(newValue)
                    }
                Button {
                    send()
                } label: {
                    Image(systemName: "paperplane.fill")
                }
                .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
        }
        .background(Color.appBackground)
        .onDisappear {
            if isCurrentlyTyping { socket.sendStopTyping() }
        }
    }

    private func send() {
        let text = input.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        socket.sendChatMessage(text)
        input = ""
        stopTypingTask?.cancel()
        if isCurrentlyTyping {
            isCurrentlyTyping = false
            socket.sendStopTyping()
        }
    }

    /// Debounced typing signal: announce "typing" on the first keystroke, then auto-clear it
    /// after a couple seconds of no further input instead of waiting for a message to be sent.
    private func handleInputChange(_ newValue: String) {
        let hasText = !newValue.trimmingCharacters(in: .whitespaces).isEmpty
        if hasText, !isCurrentlyTyping {
            isCurrentlyTyping = true
            socket.sendTyping()
        } else if !hasText, isCurrentlyTyping {
            isCurrentlyTyping = false
            socket.sendStopTyping()
        }

        stopTypingTask?.cancel()
        guard hasText else { return }
        stopTypingTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            isCurrentlyTyping = false
            socket.sendStopTyping()
        }
    }
}
