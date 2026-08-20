import SwiftUI

/// المساعد الذكي - قائمة محادثاتك، نقطة الدخول الرئيسية للميزة. متاحة لأي
/// حساب مسجّل دخول (فردي أو مؤسسي، بدون أي تقييد دور - نفس سلوك زر السايد
/// بار بالموقع). تقدر تكمل محادثة سابقة أو تبدأ وحدة جديدة عبر زر +.
struct AIConversationsListView: View {
    @State private var conversations: [AIConversationSummary] = []
    @State private var isLoading = true
    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var openedConversation: AIConversationRoute?

    var body: some View {
        Group {
            if isLoading {
                ProgressView(Loc.t("loading")).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if conversations.isEmpty {
                ContentUnavailableView(Loc.t("ai_assistant"), systemImage: "sparkles", description: Text(Loc.t("ai_conversations_empty")))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(conversations) { convo in
                    Button { openedConversation = AIConversationRoute(id: convo.id) } label: {
                        AIConversationRow(conversation: convo)
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color.appBackground)
        .navigationTitle(Loc.t("ai_assistant"))
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task { await createNewConversation() }
                } label: {
                    if isCreating { ProgressView() } else { Image(systemName: "square.and.pencil") }
                }
                .disabled(isCreating)
            }
        }
        .task { await load() }
        .refreshable { await load() }
        .navigationDestination(item: $openedConversation) { route in
            AIConversationView(conversationId: route.id) {
                Task { await load() }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let errorMessage {
                Text(errorMessage).font(.footnote).foregroundStyle(.red).padding(8)
            }
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            conversations = try await APIClient.shared.aiConversations()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func createNewConversation() async {
        isCreating = true
        do {
            let convo = try await APIClient.shared.createAiConversation()
            openedConversation = AIConversationRoute(id: convo.id)
        } catch {
            errorMessage = error.localizedDescription
        }
        isCreating = false
    }
}

private struct AIConversationRow: View {
    let conversation: AIConversationSummary

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 3) {
                Text(conversation.title.trimmingCharacters(in: .whitespaces).isEmpty ? Loc.t("ai_new_conversation_title") : conversation.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(conversation.title.trimmingCharacters(in: .whitespaces).isEmpty ? .secondary : .primary)
                if let bookTitle = conversation.bookTitle {
                    Label(bookTitle, systemImage: "book.closed").font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

/// غلاف بسيط عشان navigationDestination(item:) يحتاج نوع Identifiable -
/// نفس نمط NoteRoute بـ NotesListView.swift بالضبط
struct AIConversationRoute: Identifiable, Hashable {
    let id: String
}
