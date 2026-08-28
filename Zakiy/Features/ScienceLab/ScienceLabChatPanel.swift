import SwiftUI

/// مساعد ذكيّ مستمر طول جلسة مختبر العلوم - نفس أسلوب فقاعات AIConversationView
/// بالضبط (لون accentColor لرسالة الطالب، appCard لرد الذكاء الاصطناعي)، بس
/// بدون حفظ محادثات متعددة - محادثة واحدة مستمرة طول الجلسة (مطابق لـ
/// slSendChatMessage/slAppendChatMessage بالموقع: معرّف تفاعل واحد مستمر
/// (SL.chatInteractionId) وسياق آخر حيوان/شاشة يستكشفها الطالب).
struct ScienceLabChatPanel: View {
    let session: ScienceLabSession

    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    @State private var input = ""
    @State private var isSending = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if session.chatMessages.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "sparkles").font(.system(size: 34)).foregroundStyle(Color.accentColor)
                                Text(Loc.t("sl_chat_placeholder")).font(.footnote).foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                        }
                        ForEach(session.chatMessages) { message in
                            ScienceLabChatBubble(message: message).id(message.id)
                        }
                        if isSending {
                            HStack {
                                ScienceLabTypingIndicator()
                                Spacer()
                            }
                            .padding(.horizontal)
                            .id("typing")
                        }
                    }
                    .padding()
                }
                .onChange(of: session.chatMessages.count) { _, _ in scrollToBottom(proxy) }
                .onChange(of: isSending) { _, _ in scrollToBottom(proxy) }
            }

            Divider()

            HStack(spacing: 10) {
                TextField(Loc.t("sl_chat_placeholder"), text: $input, axis: .vertical)
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
        .navigationTitle(Loc.t("sl_chat_heading"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(Loc.t("close")) { dismiss() }
            }
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation {
            if isSending {
                proxy.scrollTo("typing", anchor: .bottom)
            } else if let last = session.chatMessages.last {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    private func send() async {
        let text = input.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        input = ""
        session.chatMessages.append(ScienceLabChatMessage(role: "user", text: text))
        session.logQuestion(text)
        isSending = true
        do {
            let result = try await APIClient.shared.scienceLabChat(
                message: text,
                lang: settings.languageCode,
                context: session.currentContextName,
                interactionId: session.chatInteractionId
            )
            session.chatInteractionId = result.interactionId
            session.chatMessages.append(ScienceLabChatMessage(role: "ai", text: result.reply))
        } catch {
            session.chatMessages.append(ScienceLabChatMessage(role: "ai", text: error.localizedDescription, isError: true))
        }
        isSending = false
    }
}

private struct ScienceLabChatBubble: View {
    let message: ScienceLabChatMessage

    var body: some View {
        HStack {
            if message.role == "user" { Spacer(minLength: 40) }
            Text(message.text)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(bubbleBackground, in: RoundedRectangle(cornerRadius: 16))
                .foregroundStyle(message.role == "user" ? Color.appAccentText : (message.isError ? .red : .primary))
            if message.role != "user" { Spacer(minLength: 40) }
        }
    }

    private var bubbleBackground: Color {
        message.role == "user" ? Color.accentColor : Color.appCard
    }
}

private struct ScienceLabTypingIndicator: View {
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
