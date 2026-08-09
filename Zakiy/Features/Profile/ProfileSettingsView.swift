import SwiftUI

struct ProfileSettingsView: View {
    @State private var bio = ""
    @State private var showArchive = true
    @State private var showStats = true
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var saveTask: Task<Void, Never>?

    var body: some View {
        Form {
            if isLoading {
                ProgressView(Loc.t("loading"))
            } else {
                Section(Loc.t("bio")) {
                    TextField(Loc.t("bio_placeholder"), text: $bio, axis: .vertical)
                        .lineLimit(3...6)
                        .onChange(of: bio) { scheduleSave() }
                }

                Section(Loc.t("privacy_settings")) {
                    Toggle(Loc.t("show_archive_on_profile"), isOn: $showArchive)
                        .onChange(of: showArchive) { scheduleSave() }
                    Toggle(Loc.t("show_stats_on_profile"), isOn: $showStats)
                        .onChange(of: showStats) { scheduleSave() }
                }

                if isSaving {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle(Loc.t("privacy_settings"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        if let profile = try? await APIClient.shared.myProfile() {
            bio = profile.bio ?? ""
            showArchive = profile.showArchive ?? true
            showStats = profile.showStats ?? true
        }
        isLoading = false
    }

    /// Debounced save: cancels any in-flight save request before starting a new one so rapid
    /// toggle-flipping can't race the initial-load response and overwrite it with stale values.
    private func scheduleSave() {
        guard !isLoading else { return }
        saveTask?.cancel()
        saveTask = Task {
            isSaving = true
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            try? await APIClient.shared.updateProfileSettings(bio: bio, showArchive: showArchive, showStats: showStats)
            if !Task.isCancelled { isSaving = false }
        }
    }
}
