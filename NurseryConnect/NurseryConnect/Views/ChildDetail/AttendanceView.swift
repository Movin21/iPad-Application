// Views/ChildDetail/AttendanceView.swift
// NurseryConnect
// Sign-in / sign-out sheet for a single child.
// Implements the EYFS Statutory Framework 2024 daily attendance register requirement.

import SwiftUI
import SwiftData

struct AttendanceView: View {
    let child: Child
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss)      private var dismiss

    @State private var notes = ""

    // MARK: Derived state

    private var todayRecord: AttendanceRecord? {
        let today = Calendar.current.startOfDay(for: Date())
        return child.attendanceRecords.first {
            Calendar.current.isDate($0.date, inSameDayAs: today)
        }
    }

    private var isPresent: Bool { todayRecord?.status == .present }

    // MARK: Body

    var body: some View {
        NavigationStack {
            Form {
                statusSection
                if let record = todayRecord { timesSection(record) }
                notesSection
                actionSection
                complianceFooter
            }
            .navigationTitle("Attendance — \(child.firstName)")
            .navigationBarTitleDisplayMode(.inline)
            .tint(Color.ncAccent)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Sections

    private var statusSection: some View {
        Section("Current Status") {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(statusColor.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: todayRecord?.status.sfSymbol ?? "person.slash")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(statusColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(child.fullName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.ncOnSurface)
                    Text(statusLabel)
                        .font(.caption)
                        .foregroundStyle(Color.ncOnSurfaceVariant)
                }

                Spacer()

                Text(isPresent ? "PRESENT" : (todayRecord?.status == .signedOut ? "SIGNED OUT" : "ABSENT"))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(statusColor.opacity(0.12), in: Capsule())
            }
            .padding(.vertical, 4)
        }
    }

    private func timesSection(_ record: AttendanceRecord) -> some View {
        Section("Today's Register") {
            if let signIn = record.signedInAt {
                LabeledContent("Signed In") {
                    Text(signIn, style: .time)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.ncSuccess)
                }
            }
            if let signOut = record.signedOutAt {
                LabeledContent("Signed Out") {
                    Text(signOut, style: .time)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.ncWarning)
                }
                LabeledContent("Session Length") {
                    Text(record.sessionDurationDescription)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.ncAccent)
                }
            }
            LabeledContent("Keyworker") {
                Text(record.signedInByName)
                    .foregroundStyle(Color.ncOnSurfaceVariant)
            }
            if !record.notes.isEmpty {
                LabeledContent("Notes") {
                    Text(record.notes)
                        .foregroundStyle(Color.ncOnSurfaceVariant)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
    }

    private var notesSection: some View {
        Section("Notes") {
            TextField("Any attendance notes (e.g. late arrival, early pickup)…",
                      text: $notes, axis: .vertical)
                .lineLimit(2...4)
        }
    }

    private var actionSection: some View {
        Section {
            if !isPresent && todayRecord?.status != .signedOut {
                Button { signIn() } label: {
                    Label("Sign In Now", systemImage: "person.fill.checkmark")
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.ncSuccess)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .listRowBackground(Color.ncSuccess.opacity(0.08))
            } else if isPresent {
                Button { signOut() } label: {
                    Label("Sign Out", systemImage: "door.left.hand.open")
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.ncAlert)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .listRowBackground(Color.ncAlert.opacity(0.08))
            } else {
                // Already signed out — show read-only state
                Label("Session Complete", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(Color.ncOnSurfaceVariant)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    private var complianceFooter: some View {
        Section {} footer: {
            Text("EYFS Statutory Framework 2024 §3.76 — Providers must maintain a daily attendance register. Records are retained for a minimum of 3 years.")
                .font(.caption2)
                .foregroundStyle(Color.ncOnSurfaceVariant)
        }
    }

    // MARK: - Helpers

    private var statusColor: Color {
        switch todayRecord?.status {
        case .present:   return Color.ncSuccess
        case .signedOut: return Color.ncWarning
        default:         return Color.ncOnSurfaceVariant
        }
    }

    private var statusLabel: String {
        switch todayRecord?.status {
        case .present:
            if let t = todayRecord?.signedInAt {
                return "Signed in at \(t.formatted(.dateTime.hour().minute()))"
            }
            return "Currently present"
        case .signedOut:
            if let t = todayRecord?.signedOutAt {
                return "Signed out at \(t.formatted(.dateTime.hour().minute()))"
            }
            return "Signed out today"
        default: return "Not signed in today"
        }
    }

    // MARK: - Actions

    private func signIn() {
        let today = Calendar.current.startOfDay(for: Date())
        if let existing = todayRecord {
            existing.signedInAt     = Date()
            existing.status         = .present
            existing.signedInByName = kKeyworkerName
            if !notes.isEmpty { existing.notes = notes }
        } else {
            let record = AttendanceRecord(
                date:            today,
                signedInAt:      Date(),
                signedInByName:  kKeyworkerName,
                status:          .present,
                notes:           notes
            )
            record.child = child
            child.attendanceRecords.append(record)
            context.insert(record)
        }
        save()
    }

    private func signOut() {
        guard let record = todayRecord else { return }
        record.signedOutAt      = Date()
        record.signedOutByName  = kKeyworkerName
        record.status           = .signedOut
        if !notes.isEmpty { record.notes = notes }
        save()
    }

    private func save() {
        try? context.save()
        HapticFeedback.success()
        dismiss()
    }
}
