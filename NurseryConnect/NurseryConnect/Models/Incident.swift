// Models/Incident.swift
// NurseryConnect
// RIDDOR-aligned incident report with body map marker support.
// ReviewStatus tracks the countersignature workflow (EYFS/Ofsted requirement).

import Foundation
import SwiftData

// MARK: - Body Map Marker

/// A single point marked on the body map SVG coordinate space (0–1 normalised).
/// Stored as a Codable struct — serialised to JSON within the Incident model.
struct BodyMapMarker: Codable, Identifiable, Equatable {
    var id: UUID
    /// Normalised x position (0 = left, 1 = right) relative to body outline
    var x: Double
    /// Normalised y position (0 = top, 1 = bottom) relative to body outline
    var y: Double
    /// Whether this marker is on the front or back body view
    var isFront: Bool
    /// Brief label — e.g. "bruise", "redness"
    var label: String

    init(x: Double, y: Double, isFront: Bool = true, label: String = "") {
        self.id = UUID()
        self.x = x
        self.y = y
        self.isFront = isFront
        self.label = label
    }
}

// MARK: - Incident Model

@Model
final class Incident {
    var id: UUID
    /// Auto-timestamp for RIDDOR audit compliance
    var timestamp: Date
    var keyworkerName: String

    var incidentType: IncidentType
    var title: String
    var descriptionText: String

    // Location within the nursery setting
    var location: String

    // Body map — stored as JSON-encoded [BodyMapMarker]
    var bodyMapMarkersData: Data?

    // RIDDOR-specific flags
    var riddorRequired: Bool
    var riddorRef: String       // Reference number if submitted to HSE

    // Witnesses
    var witnessNames: String    // Comma-separated for simplicity

    // Parent notification
    var parentNotified: Bool
    var parentNotifiedAt: Date?
    var parentSignature: String // Typed name acknowledgement (MVP)

    // Manager countersignature workflow
    var reviewStatus: ReviewStatus
    var managerName: String
    var managerNotes: String
    var countersignedAt: Date?

    var child: Child?

    // MARK: Body map helpers

    var bodyMapMarkers: [BodyMapMarker] {
        get {
            guard let data = bodyMapMarkersData else { return [] }
            return (try? JSONDecoder().decode([BodyMapMarker].self, from: data)) ?? []
        }
        set {
            bodyMapMarkersData = try? JSONEncoder().encode(newValue)
        }
    }

    var frontMarkers: [BodyMapMarker] { bodyMapMarkers.filter { $0.isFront } }
    var backMarkers:  [BodyMapMarker] { bodyMapMarkers.filter { !$0.isFront } }

    init(
        keyworkerName: String,
        incidentType: IncidentType = .accident,
        title: String = "",
        descriptionText: String = "",
        location: String = "",
        riddorRequired: Bool = false,
        witnessNames: String = ""
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.keyworkerName = keyworkerName
        self.incidentType = incidentType
        self.title = title
        self.descriptionText = descriptionText
        self.location = location
        self.bodyMapMarkersData = nil
        self.riddorRequired = riddorRequired
        self.riddorRef = ""
        self.witnessNames = witnessNames
        self.parentNotified = false
        self.parentNotifiedAt = nil
        self.parentSignature = ""
        self.reviewStatus = .pendingReview
        self.managerName = ""
        self.managerNotes = ""
        self.countersignedAt = nil
    }
}
