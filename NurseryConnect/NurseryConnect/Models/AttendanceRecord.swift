// Models/AttendanceRecord.swift
// NurseryConnect
// Daily sign-in / sign-out register for a child.
// Satisfies the nursery register obligation under the EYFS Statutory Framework 2024
// (Section 3.76: providers must keep an accurate daily record of attendance).

import Foundation
import SwiftData

// MARK: - Attendance Status

enum AttendanceStatus: String, Codable, CaseIterable {
    case present   = "Present"
    case signedOut = "Signed Out"
    case absent    = "Absent"

    var sfSymbol: String {
        switch self {
        case .present:   return "person.fill.checkmark"
        case .signedOut: return "person.fill.xmark"
        case .absent:    return "person.slash"
        }
    }

    var color: String {
        switch self {
        case .present:   return "green"
        case .signedOut: return "orange"
        case .absent:    return "red"
        }
    }
}

// MARK: - AttendanceRecord Model

@Model
final class AttendanceRecord {
    var id: UUID
    /// Normalised to start-of-day — one record per child per calendar day.
    var date: Date
    var signedInAt:  Date?
    var signedOutAt: Date?
    var signedInByName:  String
    var signedOutByName: String
    var status: AttendanceStatus
    var notes: String

    var child: Child?

    /// Duration from sign-in to sign-out (nil while still present).
    var sessionDurationMinutes: Int? {
        guard let inT = signedInAt, let outT = signedOutAt else { return nil }
        return max(0, Int(outT.timeIntervalSince(inT) / 60))
    }

    var sessionDurationDescription: String {
        guard let mins = sessionDurationMinutes else {
            return signedInAt != nil ? "In progress" : "—"
        }
        let h = mins / 60, m = mins % 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }

    init(
        date: Date = Calendar.current.startOfDay(for: Date()),
        signedInAt:  Date? = nil,
        signedOutAt: Date? = nil,
        signedInByName:  String = kKeyworkerName,
        signedOutByName: String = "",
        status: AttendanceStatus = .absent,
        notes: String = ""
    ) {
        self.id              = UUID()
        self.date            = date
        self.signedInAt      = signedInAt
        self.signedOutAt     = signedOutAt
        self.signedInByName  = signedInByName
        self.signedOutByName = signedOutByName
        self.status          = status
        self.notes           = notes
    }
}
