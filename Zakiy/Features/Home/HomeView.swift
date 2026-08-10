import SwiftUI
import UniformTypeIdentifiers

struct HomeView: View {
    @Environment(SupabaseAuthManager.self) private var auth
    @Environment(AppSettings.self) private var settings

    @State private var showFileImporter = false
    @State private var showSourceChooser = false
    @State private var showLibraryPicker = false
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var extractedText: ExtractedText?
    @State private var showPaywall = false

    private var displayName: String {
        if auth.isAuthenticated { return auth.username }
        return settings.guestName.isEmpty ? Loc.t("default_student_name") : settings.guestName
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                greetingHeader

                VStack(spacing: 14) {
                    Button {
                        if UsageLimiter.shared.canPerform(.soloSession) {
                            showSourceChooser = true
                        } else {
                            showPaywall = true
                        }
                    } label: {
                        HomeActionCard(
                            icon: "doc.text.magnifyingglass",
                            tint: .accentColor,
                            title: Loc.t("start_solo_study"),
                            subtitle: Loc.t("start_solo_study_subtitle")
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isProcessing)
                    .confirmationDialog(Loc.t("choose_file"), isPresented: $showSourceChooser, titleVisibility: .visible) {
                        Button(Loc.t("pick_from_library")) { showLibraryPicker = true }
                        Button(Loc.t("upload_from_device")) { showFileImporter = true }
                    }

                    if isProcessing {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text(Loc.t("loading")).foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 4)
                    }

                    if let errorMessage {
                        Text(errorMessage).foregroundStyle(.red).font(.footnote)
                            .padding(.horizontal, 4)
                    }

                    NavigationLink {
                        RoomLobbyView(roomType: "quiz")
                    } label: {
                        HomeActionCard(
                            icon: "person.3.fill",
                            tint: .accentColor,
                            title: Loc.t("group_room"),
                            subtitle: Loc.t("group_room_subtitle")
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        RoomLobbyView(roomType: "classroom")
                    } label: {
                        HomeActionCard(
                            icon: "person.crop.rectangle.stack.fill",
                            tint: .accentColor,
                            title: Loc.t("room_type_classroom"),
                            subtitle: Loc.t("live_lesson_subtitle")
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Color.appBackground)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 40)
            }
        }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.pdf]) { result in
            switch result {
            case .success(let url): Task { await handleUpload(url: url) }
            case .failure: errorMessage = Loc.t("error_generic")
            }
        }
        .sheet(isPresented: $showLibraryPicker) {
            LibraryPickerView { detail in
                UsageLimiter.shared.recordUsage(.soloSession)
                extractedText = ExtractedText(value: detail.extractedText)
            }
        }
        .navigationDestination(item: $extractedText) { text in
            StudyHubView(sourceText: text.value)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(triggeredBy: .soloSession)
        }
    }

    private var greetingHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(format: Loc.t("greeting_prefix"), displayName))
                .font(.largeTitle.bold())
            Text(Loc.t("home_greeting_subtitle"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 4)
    }

    private func handleUpload(url: URL) async {
        isProcessing = true
        errorMessage = nil
        defer { isProcessing = false }
        guard url.startAccessingSecurityScopedResource() else {
            errorMessage = Loc.t("error_generic")
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }
        do {
            let filename = try await APIClient.shared.upload(fileURL: url)
            let text = try await APIClient.shared.extractText(filename: filename)
            UsageLimiter.shared.recordUsage(.soloSession)
            extractedText = ExtractedText(value: text)
        } catch {
            errorMessage = Loc.t("error_generic")
        }
    }
}

struct HomeActionCard: View {
    let icon: String
    var tint: Color = .accentColor
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(Color.appAccentText)
                .frame(width: 48, height: 48)
                .background(tint.gradient, in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline).lineLimit(1)
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.forward")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(Color.appCard, in: RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
    }
}

struct ExtractedText: Identifiable, Hashable {
    let value: String
    var id: String { value.prefix(64) + "\(value.count)" }
}
