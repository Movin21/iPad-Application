// Models/DailyLog.swift  (was Observation.swift)
// NurseryConnect
// Daily observation log — EYFS area linked, timestamped & attributed.
// NOTE: named DailyLog (not Observation) to avoid shadowing the
//       Swift Observation framework used by @Observable / @Model.

import Foundation
import SwiftData

@Model
final class DailyLog {
    var id: UUID
    /// Auto-set timestamp — immutable after creation for audit trail
    var timestamp: Date
    /// Keyworker attribution — required by EYFS/Ofsted compliance
    var keyworkerName: String

    // EYFS linkage
    var eyfsArea: EYFSArea
    var activityDescription: String
    var learningNotes: String     // Brief observation notes

    // Sleep tracking
    var hasSleepRecord: Bool
    var sleepStart: Date?
    var sleepEnd: Date?

    // Nappy / toileting
    var hasNappyRecord: Bool
    var nappyType: NappyType?
    var nappyNotes: String

    // Mood & wellbeing
    var mood: MoodLevel
    var wellbeingNotes: String

    // Back-reference to parent child
    var child: Child?

    var sleepDurationMinutes: Int? {  // computed — not persisted
        guard let start = sleepStart, let end = sleepEnd else { return nil }
        return Int(end.timeIntervalSince(start) / 60)
    }

    var sleepDurationDescription: String {
        guard let mins = sleepDurationMinutes else { return "N/A" }
        let h = mins / 60, m = mins % 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }

    init(
        keyworkerName: String,
        eyfsArea: EYFSArea = .communication,
        activityDescription: String = "",
        learningNotes: String = "",
        hasSleepRecord: Bool = false,
        sleepStart: Date? = nil,
        sleepEnd: Date? = nil,
        hasNappyRecord: Bool = false,
        nappyType: NappyType? = nil,
        nappyNotes: String = "",
        mood: MoodLevel = .happy,
        wellbeingNotes: String = ""
    ) {
        self.id = UUID()
        self.timestamp = Date()         // Auto-timestamp on creation
        self.keyworkerName = keyworkerName
        self.eyfsArea = eyfsArea
        self.activityDescription = activityDescription
        self.learningNotes = learningNotes
        self.hasSleepRecord = hasSleepRecord
        self.sleepStart = sleepStart
        self.sleepEnd = sleepEnd
        self.hasNappyRecord = hasNappyRecord
        self.nappyType = nappyType
        self.nappyNotes = nappyNotes
        self.mood = mood
        self.wellbeingNotes = wellbeingNotes
    }
}
