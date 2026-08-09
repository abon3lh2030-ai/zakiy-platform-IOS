import SwiftUI

struct ProfileSettingsView: View {
    let profile: UserProfile

    @State private var bio = ""
    @State private var isPrivate = false
    @State private var showPerformance = true
    @State private var showLibrary = true
    @State private var showArchive = true
    @State private var showFriends = true
    @State private var isSaving = false
    @State private var saveTask: Task<Void, Never>?

    var body: some View {
        Form {
            Section(Loc.t("bio")) {
                TextField(Loc.t("bio_placeholder"), text: $bio, axis: .vertical)
                    .lineLimit(3...6)
                    .onChange(of: bio) { scheduleSave() }
            }

            Section(Loc.t("privacy_settings")) {
                Toggle(Loc.t("private_profile"), isOn: $isPrivate)
                    .onChange(of: isPrivate) { scheduleSave() }
                Toggle(Loc.t("show_performance_on_profile"), isOn: $showPerformance)
                    .onChange(of: showPerformance) { scheduleSave() }
                Toggle(Loc.t("show_library_on_profile"), isOn: $showLibrary)
                    .onChange(of: showLibrary) { scheduleSave() }
                Toggle(Loc.t("show_archive_on_profile"), isOn: $showArchive)
                    .onChange(of: showArchive) { scheduleSave() }
                Toggle(Loc.t("show_friends_on_profile"), isOn: $showFriends)
                    .onChange(of: showFriends) { scheduleSave() }
            }

            if isSaving {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            }
        }
        .navigationTitle(Loc.t("privacy_settings"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            bio = profile.bio ?? ""
            isPrivate = profile.isPrivate
            showPerformance = profile.showPerformance ?? true
            showLibrary = profile.showLibrary ?? true
            showArchive = profile.showArchive ?? true
            showFriends = profile.showFriends ?? true
        }
    }

    /// Debounced save: cancels any in-flight save request before starting a new one so rapid
    /// toggle-flipping can't race a stale request and overwrite newer values.
    private func scheduleSave() {
        saveTask?.cancel()
        let patch: [String: Any] = [
            "bio": bio,
            "is_private": isPrivate,
            "show_performance": showPerformance,
            "show_library": showLibrary,
            "show_archive": showArchive,
            "show_friends": showFriends,
        ]
        saveTask = Task {
            isSaving = true
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            try? await APIClient.shared.updateMyProfile(patch)
            if !Task.isCancelled { isSaving = false }
        }
    }
}
