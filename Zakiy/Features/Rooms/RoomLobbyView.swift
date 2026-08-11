import SwiftUI

/// Room entry screen: lets the user either create a fresh room of `roomType`, or join an
/// existing one by typing/scanning its code — matches the merged create+join layout from the
/// previous app build (one screen instead of two separate flows).
struct RoomLobbyView: View {
    let roomType: String

    @Environment(SupabaseAuthManager.self) private var auth
    @Environment(AppSettings.self) private var settings

    @State private var guestName = ""
    @State private var joinCode = ""
    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var showPaywall = false
    @State private var showScanner = false
    @State private var destination: RoomDestination?

    private struct RoomDestination: Identifiable, Hashable {
        let code: String
        let isCreator: Bool
        var id: String { code + "\(isCreator)" }
    }

    private var limitedAction: LimitedAction { roomType == "classroom" ? .liveLesson : .groupRoom }

    private var displayName: String {
        if auth.isAuthenticated { return auth.username }
        let trimmed = guestName.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? Loc.t("default_student_name") : trimmed
    }

    var body: some View {
        // لازم حساب مسجّل عشان تدخل أي درس مباشر أو جلسة جماعية - ما فيه
        // دخول كضيف إطلاقًا (نفس القيد اللي الباك إند يفرضه الحين)
        if !auth.isAuthenticated {
            loginRequiredView
        } else {
            roomLobbyContent
        }
    }

    private var loginRequiredView: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill").font(.largeTitle).foregroundStyle(.secondary)
            Text(Loc.t("login_required_for_rooms")).multilineTextAlignment(.center).foregroundStyle(.secondary)
            NavigationLink(Loc.t("login")) { LoginView() }
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
        .navigationTitle(roomType == "classroom" ? Loc.t("room_type_classroom") : Loc.t("group_room"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var roomLobbyContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                Button {
                    Task { await createRoom() }
                } label: {
                    HStack {
                        Text(Loc.t("create_room"))
                        Spacer()
                        if isCreating {
                            ProgressView()
                        } else {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    .padding(16)
                }
                .background(Color.appCard, in: RoundedRectangle(cornerRadius: 16))
                .disabled(isCreating)

                if let errorMessage {
                    Text(errorMessage).font(.footnote).foregroundStyle(.red)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text(Loc.t("join_by_code"))
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .trailing)

                    VStack(spacing: 0) {
                        TextField(Loc.t("room_code_placeholder"), text: $joinCode)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .submitLabel(.join)
                            .onSubmit { joinByCode() }
                            .padding(16)

                        Divider()

                        Button {
                            showScanner = true
                        } label: {
                            HStack {
                                Text(Loc.t("scan_qr_code"))
                                Spacer()
                                Image(systemName: "qrcode.viewfinder")
                                    .foregroundStyle(Color.accentColor)
                            }
                            .padding(16)
                        }
                    }
                    .background(Color.appCard, in: RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding()
        }
        .background(Color.appBackground)
        .navigationTitle(roomType == "classroom" ? Loc.t("room_type_classroom") : Loc.t("group_room"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPaywall) {
            PaywallView(triggeredBy: limitedAction)
        }
        .sheet(isPresented: $showScanner) {
            QRScannerView(onRoomCode: { code in
                showScanner = false
                joinCode = code
                joinByCode()
            })
        }
        .navigationDestination(item: $destination) { dest in
            RoomContainerView(roomCode: dest.code, roomType: roomType, isCreator: dest.isCreator, guestName: displayName)
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
            destination = RoomDestination(code: code, isCreator: true)
        } catch {
            errorMessage = Loc.t("error_generic")
        }
        isCreating = false
    }

    private func joinByCode() {
        let code = joinCode.trimmingCharacters(in: .whitespaces).uppercased()
        guard !code.isEmpty else { return }
        destination = RoomDestination(code: code, isCreator: false)
    }
}
