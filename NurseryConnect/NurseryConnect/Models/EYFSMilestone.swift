// Models/EYFSMilestone.swift
// NurseryConnect
// EYFS 2024 developmental milestone tracking per child.

import Foundation
import SwiftData

@Model
final class EYFSMilestone {
    var id: UUID
    var eyfsArea: EYFSArea
    var milestoneDescription: String
    /// Typical age band — e.g. "Birth–3", "3–4 years"
    var ageBand: String
    var status: MilestoneStatus
    var achievedDate: Date?
    var notes: String
    /// Last updated timestamp (auto-set on status change)
    var lastUpdated: Date
    var keyworkerName: String

    var child: Child?

    init(
        eyfsArea: EYFSArea,
        milestoneDescription: String,
        ageBand: String = "",
        status: MilestoneStatus = .notStarted,
        keyworkerName: String = ""
    ) {
        self.id = UUID()
        self.eyfsArea = eyfsArea
        self.milestoneDescription = milestoneDescription
        self.ageBand = ageBand
        self.status = status
        self.achievedDate = nil
        self.notes = ""
        self.lastUpdated = Date()
        self.keyworkerName = keyworkerName
    }
}

// MARK: - Default EYFS 2024 Milestones Catalogue

/// Seed data — representative EYFS 2024 milestones.
/// Call `EYFSMilestoneCatalogue.defaults(for:)` when creating a new child profile.
enum EYFSMilestoneCatalogue {
    struct Template {
        let area: EYFSArea
        let description: String
        let ageBand: String
    }

    static let all: [Template] = [
        // Communication & Language
        Template(area: .communication, description: "Listens and responds to simple instructions",         ageBand: "Birth–3"),
        Template(area: .communication, description: "Uses sentences of 4–6 words",                         ageBand: "3–4 years"),
        Template(area: .communication, description: "Asks 'why' and 'how' questions",                      ageBand: "3–4 years"),
        Template(area: .communication, description: "Maintains attention in group situations",              ageBand: "4–5 years"),

        // Physical
        Template(area: .physical, description: "Walks up and down stairs, alternating feet",               ageBand: "Birth–3"),
        Template(area: .physical, description: "Runs safely, changing direction",                          ageBand: "3–4 years"),
        Template(area: .physical, description: "Uses scissors with two fingers",                           ageBand: "3–4 years"),
        Template(area: .physical, description: "Holds pencil with comfortable grip",                       ageBand: "4–5 years"),

        // Personal, Social & Emotional
        Template(area: .personalSocial, description: "Separates from main carer with support",             ageBand: "Birth–3"),
        Template(area: .personalSocial, description: "Initiates play with other children",                 ageBand: "3–4 years"),
        Template(area: .personalSocial, description: "Shows empathy towards peers",                        ageBand: "3–4 years"),
        Template(area: .personalSocial, description: "Is confident to try new activities",                 ageBand: "4–5 years"),

        // Literacy
        Template(area: .literacy, description: "Enjoys sharing books with adults",                         ageBand: "Birth–3"),
        Template(area: .literacy, description: "Recognises own name in print",                             ageBand: "3–4 years"),
        Template(area: .literacy, description: "Blends sounds in CVC words",                               ageBand: "4–5 years"),
        Template(area: .literacy, description: "Writes own first name",                                    ageBand: "4–5 years"),

        // Mathematics
        Template(area: .mathematics, description: "Counts reliably to 5",                                  ageBand: "Birth–3"),
        Template(area: .mathematics, description: "Matches numeral to quantity up to 5",                   ageBand: "3–4 years"),
        Template(area: .mathematics, description: "Understands concepts of more/less",                     ageBand: "3–4 years"),
        Template(area: .mathematics, description: "Orders numbers 1–10",                                   ageBand: "4–5 years"),

        // Understanding the World
        Template(area: .understanding, description: "Shows interest in the lives of familiar people",      ageBand: "Birth–3"),
        Template(area: .understanding, description: "Makes observations about plants/animals",             ageBand: "3–4 years"),
        Template(area: .understanding, description: "Uses simple technology with support",                 ageBand: "3–4 years"),
        Template(area: .understanding, description: "Talks about past and future events",                  ageBand: "4–5 years"),

        // Expressive Arts & Design
        Template(area: .expressive, description: "Explores and uses different materials",                  ageBand: "Birth–3"),
        Template(area: .expressive, description: "Represents own ideas through drawing/painting",          ageBand: "3–4 years"),
        Template(area: .expressive, description: "Sings songs with correct pitch",                        ageBand: "3–4 years"),
        Template(area: .expressive, description: "Creates own simple dance movements",                    ageBand: "4–5 years"),
    ]

    /// Returns freshly-initialised EYFSMilestone objects seeded from the catalogue.
    static func defaults(keyworkerName: String) -> [EYFSMilestone] {
        all.map {
            EYFSMilestone(
                eyfsArea: $0.area,
                milestoneDescription: $0.description,
                ageBand: $0.ageBand,
                keyworkerName: keyworkerName
            )
        }
    }
}
