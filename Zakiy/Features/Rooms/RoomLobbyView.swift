import SwiftUI

/// Pre-creation screen: lets the user pick a display name (for guests) then creates a fresh
/// room of `roomType` on the backend and hands off to `RoomContainerView`.
struct RoomLobbyView: View {
    let roomType: String

    @Environment(SupabaseAuthManager.self) private var auth
    @Environment(AppSettings.self) private var settings

    @State private var guestName = ""
    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var showPaywall = false
    @State private var createdCode: CreatedRoomCode?

    private struct CreatedRoomCode: Identifiable, Hashable {
        let code: String
        var id: String { code }
    }

    private var limitedAction: LimitedAction { roomType == "classroom" ? .liveLesson : .groupRoom }

    private var displayName: String {
        if auth.isAuthenticated { return auth.username }
        let trimmed = guestName.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? Loc.t("default_student_name") : trimmed
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: roomType == "classroom" ? "person.crop.rectangle.stack.fill" : "person.3.fill")
                .font(.system(size: 50))
                .foregroundStyle(Color.accentColor)

            Text(roomType == "classroom" ? Loc.t("room_type_classroom") : Loc.t("group_room"))
                .font(.title2.bold())

            if !auth.isAuthenticated {
                TextField(Loc.t("your_name"), text: $guestName)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, 40)
            }

            if let errorMessage {
                Text(errorMessage).font(.footnote).foregroundStyle(.red)
            }

            Button {
                Task { await createRoom() }
            } label: {
                if isCreating {
                    ProgressView().frame(maxWidth: .infinity)
                } else {
                    Text(Loc.t("create_room")).frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.appPrimary)
            .padding(.horizontal, 40)
            .disabled(isCreating)

            Spacer()
        }
        .background(Color.appBackground)
        .navigationTitle(Loc.t("create_room"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPaywall) {
            PaywallView(triggeredBy: limitedAction)
        }
        .navigationDestination(item: $createdCode) { created in
            RoomContainerView(roomCode: created.code, roomType: roomType, isCreator: true, guestName: displayName)
        }
    }

    private func createRoom() async {
        guard UsageLimiter.shared.canPerform(limitedAction) else {
            showPaywall = true
            return
        }
        isCreating = true
        errorMessage = nil
        do {
            let code = try await APIClient.shared.createRoom(roomType: roomType)
            UsageLimiter.shared.recordUsage(limitedAction)
            createdCode = CreatedRoomCode(code: code)
        } catch {
            errorMessage = Loc.t("error_generic")
        }
        isCreating = false
    }
}
