import SwiftUI

struct TeacherRosterView: View {
    @Binding var selectedClassId: String?

    @State private var students: [SchoolStudent] = []
    @State private var isLoading = true

    @State private var broadcastBody = ""
    @State private var isBroadcasting = false
    @State private var broadcastMessage: String?

    var body: some View {
        List {
            Section {
                if isLoading {
                    ProgressView()
                } else if filteredStudents.isEmpty {
                    Text(Loc.t("teacher_no_students")).foregroundStyle(.secondary)
                } else {
                    ForEach(filteredStudents) { student in
                        NavigationLink {
                            InstitutionalProfileDetailView(userId: student.userId, username: student.username) { userId in
                                try await APIClient.shared.teacherStudentProfile(userId: userId)
                            }
                        } label: {
                            Text(student.username)
                        }
                    }
                }
            }

            Section(Loc.t("broadcast_students_heading")) {
                TextField(Loc.t("ph_broadcast_body"), text: $broadcastBody, axis: .vertical)
                    .lineLimit(3...6)
                Button {
                    Task { await sendBroadcast() }
                } label: {
                    if isBroadcasting {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text(Loc.t("btn_send_broadcast")).frame(maxWidth: .infinity)
                    }
                }
                .disabled(isBroadcasting || broadcastBody.trimmingCharacters(in: .whitespaces).isEmpty)
                if let broadcastMessage {
                    Text(broadcastMessage).font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    private var filteredStudents: [SchoolStudent] {
        guard let selectedClassId else { return students }
        return students.filter { $0.classId == selectedClassId }
    }

    private func load() async {
        isLoading = true
        let roster = try? await APIClient.shared.teacherRoster()
        students = roster?.students ?? []
        isLoading = false
    }

    private func sendBroadcast() async {
        isBroadcasting = true
        broadcastMessage = nil
        do {
            let count = try await APIClient.shared.teacherBroadcast(body: broadcastBody, classId: selectedClassId)
            broadcastMessage = String(format: Loc.t("broadcast_sent_msg"), count)
            broadcastBody = ""
        } catch {
            broadcastMessage = Loc.t("error_generic")
        }
        isBroadcasting = false
    }
}

/// شاشة بروفايل مؤسسي مشتركة (يفتحها المعلم لطالبه، أو مدير المدرسة لأي حساب
/// بمدرسته) - `fetch` يحدد أي endpoint يُنادى، الشكل المرجّع نفسه بالضبط.
struct InstitutionalProfileDetailView: View {
    let userId: String
    let username: String
    let fetch: (String) async throws -> InstitutionalProfile

    @State private var profile: InstitutionalProfile?
    @State private var isLoading = true

    var body: some View {
        List {
            if let profile {
                Section(Loc.t("performance")) {
                    if let perf = profile.performance {
                        LabeledContent(Loc.t("th_attempts"), value: "\(perf.attemptsCount)")
                        LabeledContent(Loc.t("th_avg_score"), value: "\(perf.avgScore)%")
                        LabeledContent(Loc.t("th_study_minutes"), value: "\(perf.totalStudyMinutes)")
                        LabeledContent(Loc.t("th_streak"), value: "\(perf.currentStreak)")
                    }
                }
                Section(Loc.t("archive")) {
                    if let archive = profile.archive, !archive.isEmpty {
                        ForEach(archive) { item in
                            Text(item.roomType ?? item.roomCode ?? "—")
                        }
                    } else {
                        Text(Loc.t("teacher_student_no_archive")).foregroundStyle(.secondary)
                    }
                }
            } else if isLoading {
                ProgressView().frame(maxWidth: .infinity)
            }
        }
        .navigationTitle(username)
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        profile = try? await fetch(userId)
        isLoading = false
    }
}
