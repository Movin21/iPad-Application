// ViewModels/DashboardViewModel.swift
// NurseryConnect
// Manages the keyworker dashboard: filtered child list + sample data seeding.

import Foundation
import SwiftData
import Observation

/// Hard-coded keyworker identity for MVP (no login screen).
/// In production this would come from an authenticated session.
let kKeyworkerName = "Sarah Thompson"

@Observable
final class DashboardViewModel {
    // MARK: - State

    var searchText: String = ""
    var showingAddChild: Bool = false

    // MARK: - Child filtering (GDPR isolation)

    /// Filters to only this keyworker's assigned children.
    func filteredChildren(_ children: [Child]) -> [Child] {
        let assigned = children.filter {
            $0.assignedKeyworkerName == kKeyworkerName
        }
        guard !searchText.isEmpty else { return assigned }
        return assigned.filter {
            $0.fullName.localizedCaseInsensitiveContains(searchText)
        }
    }

    // MARK: - Stats for dashboard header

    func todayObservationCount(for children: [Child]) -> Int {
        let today = Calendar.current.startOfDay(for: Date())
        return filteredChildren(children).flatMap(\.observations).filter {
            $0.timestamp >= today
        }.count
    }

    func pendingIncidentCount(for children: [Child]) -> Int {
        filteredChildren(children).flatMap(\.incidents).filter {
            $0.reviewStatus == .pendingReview
        }.count
    }

    // MARK: - Sample data seeding

    /// Seeds sample children if none are assigned to this keyworker.
    /// Called once on app launch to ensure the dashboard is never empty on first run.
    func seedSampleDataIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<Child>(
            predicate: #Predicate { $0.assignedKeyworkerName == kKeyworkerName }
        )
        let existing = (try? context.fetch(descriptor)) ?? []
        guard existing.isEmpty else { return }

        let samples: [(String, String, Int, [String], String)] = [
            ("Amelia",  "Clarke",  3,  ["Nuts", "Dairy"],   "Carries EpiPen. Notify parent immediately for any reaction."),
            ("Oscar",   "Bennett", 4,  [],                  ""),
            ("Isla",    "Morris",  2,  ["Gluten"],          "Coeliac — strictly no wheat products."),
            ("Noah",    "Walker",  3,  [],                  "Mild asthma. Inhaler in red medical cabinet."),
            ("Sophia",  "Taylor",  4,  ["Eggs"],            ""),
        ]

        let calendar = Calendar.current
        for (first, last, ageYears, allergies, notes) in samples {
            let dob = calendar.date(byAdding: .year, value: -ageYears, to: Date()) ?? Date()
            let child = Child(
                firstName: first,
                lastName: last,
                dateOfBirth: dob,
                assignedKeyworkerName: kKeyworkerName,
                allergies: allergies,
                medicalNotes: notes,
                emergencyContactName: "\(last) Parent",
                emergencyContactPhone: "07700 9000\(Int.random(in: 10...99))"
            )
            // Seed default EYFS milestones
            let milestones = EYFSMilestoneCatalogue.defaults(keyworkerName: kKeyworkerName)
            milestones.forEach { $0.child = child }
            child.milestones = milestones
            context.insert(child)
        }

        try? context.save()
    }
}
