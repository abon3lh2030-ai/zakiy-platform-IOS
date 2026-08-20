import SwiftUI

/// محادثة وحدة مع المساعد الذكي - سولفة حرة أو نتيجة تلخيص كتاب. زر الرجوع
/// القياسي بأعلى يسار الشاشة يودّي لقائمة المحادثات (مطابق لسلوك زر ⋮
/// بالموقع، بس بأسلوب iOS القياسي بدل زر مخصص). زر الكتاب جمب صندوق الكتابة
/// يفتح صفحة اختيار كتاب يلخّصه ذكيّ داخل نفس المحادثة.
struct AIConversationView: View {
    let conversationId: String
    var onChanged: () -> Void = {}

    @Environment(AppSettings.self) private var settings

    @State private var title = ""
    @State private var messages: [AIMessage] = []
    @State private var input = ""
    @State private var isLoading = true
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var showBookPicker = false

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                ProgressView(Loc.t("loading")).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            if messages.isEmpty {
                                VStack(spacing: 8) {
                                    Image(systemName: "sparkles").font(.system(size: 34)).foregroundStyle(Color.accentColor)
                                    Text(Loc.t("ai_empty_conversation")).font(.footnote).foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.top, 40)
                            }
                            ForEach(messages) { message in
                                AIMessageBubble(message: message).id(message.id)
                            }
                            if isSending {
                                HStack {
                                    AITypingIndicator()
                                    Spacer()
                                }
                                .padding(.horizontal)
                                .id("typing")
                            }
                        }
                        .padding()
                    }
                    .onChange(of: messages.count) { scrollToBottom(proxy) }
                    .onChange(of: isSending) { scrollToBottom(proxy) }
                }
            }

            if let errorMessage {
                Text(errorMessage).font(.footnote).foregroundStyle(.red).padding(.horizontal)
            }

            Divider()

            HStack(spacing: 10) {
                Button { showBookPicker = true } label: {
                    Image(systemName: "book.closed.fill")
                        .font(.title3)
                        .foregroundStyle(Color.accentColor)
                }

                TextField(Loc.t("ai_message_placeholder"), text: $input, axis: .vertical)
                    .lineLimit(1...4)
                    .textFieldStyle(.roundedBorder)

                Button {
                    Task { await sendTextMessage() }
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
        .navigationTitle(title.trimmingCharacters(in: .whitespaces).isEmpty ? Loc.t("ai_new_conversation_title") : title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .onDisappear { onChanged() }
        .sheet(isPresented: $showBookPicker) {
            AIBookPickerView { bookTitle, bookText in
                showBookPicker = false
                Task { await sendBookSummary(title: bookTitle, text: bookText) }
            }
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation {
            if isSending {
                proxy.scrollTo("typing", anchor: .bottom)
            } else if let last = messages.last {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let convo = try await APIClient.shared.aiConversation(id: conversationId)
            title = convo.title
            messages = convo.messages
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func sendTextMessage() async {
        let text = input.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        input = ""
        await send(displayText: text, content: text, bookTitle: nil, bookText: nil)
    }

    private func sendBookSummary(title bookTitle: String, text bookText: String) async {
        let displayText = "📚 \(Loc.t("ai_summarize_book")): \(bookTitle)"
        await send(displayText: displayText, content: nil, bookTitle: bookTitle, bookText: bookText)
    }

    private func send(displayText: String, content: String?, bookTitle: String?, bookText: String?) async {
        errorMessage = nil
        messages.append(AIMessage(role: "user", content: displayText, createdAt: nil))
        isSending = true
        do {
            let result = try await APIClient.shared.sendAiMessage(
                conversationId: conversationId,
                content: content,
                bookTitle: bookTitle,
                bookText: bookText,
                lang: settings.languageCode
            )
            messages.append(AIMessage(role: "assistant", content: result.reply, createdAt: nil))
            if let newTitle = result.title, !newTitle.isEmpty { title = newTitle }
            onChanged()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSending = false
    }
}

private struct AIMessageBubble: View {
    let message: AIMessage

    var body: some View {
        HStack {
            if message.role == "user" { Spacer(minLength: 40) }
            Text(message.content)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(message.role == "user" ? Color.accentColor : Color.appCard, in: RoundedRectangle(cornerRadius: 16))
                .foregroundStyle(message.role == "user" ? Color.appAccentText : .primary)
            if message.role != "user" { Spacer(minLength: 40) }
        }
    }
}

private struct AITypingIndicator: View {
    @State private var animate = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 6, height: 6)
                    .offset(y: animate ? -3 : 0)
                    .animation(.easeInOut(duration: 0.5).repeatForever().delay(Double(i) * 0.15), value: animate)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.appCard, in: RoundedRectangle(cornerRadius: 16))
        .onAppear { animate = true }
    }
}
