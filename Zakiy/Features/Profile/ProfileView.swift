import SwiftUI

struct ProfileView: View {
    /// nil means "my own profile"
    let userId: String?

    @Environment(SupabaseAuthManager.self) private var auth
    @State private var profile: UserProfile?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showEditProfile = false
    @State private var showMyQR = false

    private var isOwnProfile: Bool {
        (userId == nil) || (userId == auth.userId)
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView(Loc.t("loading")).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let profile {
                ScrollView {
                    VStack(spacing: 16) {
                        identityCard(profile)

                        if let performance = profile.performance {
                            performanceCard(performance)
                        }

                        if let library = profile.library {
                            libraryCard(library)
                        }

                        if let archive = profile.archive, !archive.isEmpty {
                            archiveCard(archive)
                        }

                        friendActionRow(profile)
                    }
                    .padding()
                }
            } else {
                ContentUnavailableView(Loc.t("profile"), systemImage: "person.crop.circle.badge.exclamationmark", description: Text(errorMessage ?? Loc.t("error_generic")))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color.appBackground)
        .navigationTitle(isOwnProfile ? Loc.t("my_profile") : Loc.t("profile"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isOwnProfile {
                // .topBarTrailing, not .topBarLeading — "leading" is direction-aware and in our
                // RTL app resolves to the physical right edge, which crowded it right next to the
                // title. .trailing puts it on the actual physical left, as requested.
                ToolbarItem(placement: .topBarTrailing) {
                    Button(Loc.t("edit")) { showEditProfile = true }
                }
            }
        }
        .sheet(isPresented: $showEditProfile) {
            NavigationStack { EditProfileView() }
        }
        .sheet(isPresented: $showMyQR) { MyQRCodeView() }
        .task { await load() }
    }

    // MARK: - Identity card (avatar, name, school, bio, QR)

    private func identityCard(_ profile: UserProfile) -> some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.blue, .teal], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 84, height: 84)
                Text(String(profile.username.prefix(1)))
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
            }

            Text(profile.username).font(.title3.bold())

            if let schoolName = profile.schoolName, !schoolName.isEmpty {
                Label(schoolName, systemImage: "graduationcap.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.teal)
            }

            if let bio = profile.bio, !bio.isEmpty {
                Text(bio)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if isOwnProfile {
                Button {
                    showMyQR = true
                } label: {
                    Label(Loc.t("my_qr_code"), systemImage: "qrcode")
                        .font(.footnote.bold())
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
                .tint(Color.accentColor)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.appCard, in: RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - Performance card (4 colored stat tiles)

    private func performanceCard(_ performance: ProfilePerformanceSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(Loc.t("performance"), systemImage: "chart.line.uptrend.xyaxis").font(.headline)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                statTile(value: "\(performance.currentStreak)", icon: "flame.fill", label: Loc.t("streak_label"), tint: .orange)
                statTile(value: "\(performance.attemptsCount)", icon: "checkmark.circle.fill", label: Loc.t("total_attempts"), tint: .gray)
                statTile(value: "\(performance.avgScore)%", icon: "percent", label: Loc.t("average_score"), tint: Color.accentColor)
                statTile(value: "\(performance.totalStudyMinutes)", icon: "clock.fill", label: Loc.t("study_hours_label"), tint: .yellow)
            }
        }
        .padding()
        .background(Color.appCard, in: RoundedRectangle(cornerRadius: 18))
    }

    private func statTile(value: String, icon: String, label: String, tint: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.subheadline).foregroundStyle(tint)
            Text(value).font(.title3.bold())
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Library / Archive preview cards

    private func libraryCard(_ library: ProfileLibrarySummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(Loc.t("library"), systemImage: "books.vertical.fill").font(.headline)
            Text(String(format: Loc.t("library_count_label"), library.count)).font(.subheadline).foregroundStyle(.secondary)
            ForEach(library.titles, id: \.self) { title in
                Text("· \(title)").font(.footnote)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.appCard, in: RoundedRectangle(cornerRadius: 18))
    }

    private func archiveCard(_ archive: [SessionArchiveItem]) -> some View {
        NavigationLink {
            if isOwnProfile {
                ArchiveListView()
            } else {
                ProfileArchiveListView(items: archive)
            }
        } label: {
            HStack {
                Label(Loc.t("archive"), systemImage: "archivebox.fill").font(.headline)
                Spacer()
                Image(systemName: "chevron.forward").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
            }
            .padding()
            .background(Color.appCard, in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }

    // MARK: - Friend action row (other users' profiles only)

    @ViewBuilder
    private func friendActionRow(_ profile: UserProfile) -> some View {
        if !isOwnProfile {
            if profile.friendStatus == "none" {
                Button {
                    Task { await sendFriendRequest() }
                } label: {
                    Text(Loc.t("add_friend")).frame(maxWidth: .infinity)
                }
                .buttonStyle(.appPrimary)
            } else if profile.friendStatus == "pending_sent" {
                Text(Loc.t("friend_request_sent")).foregroundStyle(.secondary)
            } else if profile.friendStatus == "pending_received" {
                Text(Loc.t("incoming_request_notice")).foregroundStyle(.secondary)
            } else if profile.friendStatus == "friends" {
                Label(Loc.t("friends"), systemImage: "checkmark.circle.fill").foregroundStyle(Color.accentColor)
            }
        }
    }

    private func load() async {
        isLoading = true
        let targetId = userId ?? auth.userId ?? ""
        do {
            profile = try await APIClient.shared.fullProfile(userId: targetId)
        } catch {
            errorMessage = Loc.t("error_generic")
        }
        isLoading = false
    }

    private func sendFriendRequest() async {
        guard let userId else { return }
        try? await APIClient.shared.sendFriendRequest(toUserId: userId)
        await load()
    }
}

/// Read-only archive list for viewing another user's shared sessions (their own APIClient.sessionsArchive()
/// call would return *my* sessions, not theirs — so we just render the items already embedded in their profile).
private struct ProfileArchiveListView: View {
    let items: [SessionArchiveItem]
    @State private var selected: SessionArchiveItem?

    var body: some View {
        List(items) { item in
            Button { selected = item } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.hostName.map { String(format: Loc.t("session_hosted_by"), $0) } ?? item.roomCode ?? Loc.t("archive"))
                        .font(.headline)
                    if let createdAt = item.createdAt {
                        Text(createdAt).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 2)
            }
            .buttonStyle(.plain)
        }
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .navigationTitle(Loc.t("archive"))
        .navigationDestination(item: $selected) { item in
            ArchiveDetailView(item: item)
        }
    }
}
