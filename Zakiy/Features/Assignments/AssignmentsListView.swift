import SwiftUI

/// دفتر الواجبات - معلم أو طالب بس (الباك إند يرفض أي حساب فردي عبر
/// require_role). معلم يشوف واجباته وينشئ جديد، طالب يشوف واجباته وحالة
/// تسليمها. كل واجب يفتح بصفحته الخاصة (AssignmentDetailView).
struct AssignmentsListView: View {
    @Environment(SupabaseAuthManager.self) private var auth

    @State private var assignments: [AssignmentSummary] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showCreateSheet = false
    @State private var openedAssignment: AssignmentRoute?

    private var isTeacher: Bool { auth.role == "teacher" }

    var body: some View {
        Group {
            if isLoading {
                ProgressView(Loc.t("loading")).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage {
                ContentUnavailableView(Loc.t("assignments"), systemImage: "exclamationmark.triangle", description: Text(errorMessage))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if assignments.isEmpty {
                ContentUnavailableView(Loc.t("assignments"), systemImage: "doc.text", description: Text(Loc.t("assignments_empty")))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(assignments) { assignment in
                    Button { openedAssignment = AssignmentRoute(id: assignment.id) } label: {
                        AssignmentRow(assignment: assignment, isTeacher: isTeacher)
                    }
                    .buttonStyle(.plain)
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color.appBackground)
        .navigationTitle(Loc.t("assignments_heading"))
        .toolbar {
            if isTeacher {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showCreateSheet = true } label: { Image(systemName: "plus") }
                }
            }
        }
        .task { await load() }
        .refreshable { await load() }
        .sheet(isPresented: $showCreateSheet) {
            AssignmentCreateSheet { await load() }
        }
        .navigationDestination(item: $openedAssignment) { route in
            AssignmentDetailView(assignmentId: route.id, isTeacher: isTeacher)
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            assignments = isTeacher ? try await APIClient.shared.teacherAssignments() : try await APIClient.shared.studentAssignments()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

private struct AssignmentRow: View {
    let assignment: AssignmentSummary
    let isTeacher: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(assignment.title).font(.body.weight(.medium))
                Text(assignment.subject).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            statusBadge
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var statusBadge: some View {
        if isTeacher {
            let done = assignment.submittedCount ?? 0
            let total = assignment.totalCount ?? 0
            Text(Loc.t("assignment_submitted_count", done, total))
                .font(.caption.weight(.semibold))
                .foregroundStyle(done >= total && total > 0 ? Color.green : Color.orange)
        } else {
            Text(assignment.submitted == true ? Loc.t("assignment_status_done") : Loc.t("assignment_status_pending"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(assignment.submitted == true ? Color.green : Color.orange)
        }
    }
}

/// غلاف Identifiable بسيط لـ navigationDestination(item:) بدل توسيع String
/// نفسه عالميًا (نفس الأسلوب المتبع بـ NoteRoute بميزة الملاحظات)
struct AssignmentRoute: Identifiable, Hashable {
    let id: String
}
