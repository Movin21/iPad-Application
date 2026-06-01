// ViewModels/ChildDetailViewModel.swift
// NurseryConnect
// Logic for the child detail screen: recent logs, quick stats, alert state.

import Foundation
import SwiftData
import Observation

@Observable
final class ChildDetailViewModel {
    // Active sheet/navigation flags
    var showingLogForm      = false
    var showingMealLog      = false
    var showingIncidentForm = false
    var showingEYFSTracker  = false
    var showingAttendance   = false

    // MARK: - Today's summary

    func todayObservations(for child: Child) -> [DailyLog] {
        let today = Calendar.current.startOfDay(for: Date())
        return child.observations
            .filter { $0.timestamp >= today }
            .sorted { $0.timestamp > $1.timestamp }
    }

    func todayMeals(for child: Child) -> [MealRecord] {
        let today = Calendar.current.startOfDay(for: Date())
        return child.mealRecords
            .filter { $0.timestamp >= today }
            .sorted { $0.timestamp > $1.timestamp }
    }

    func latestMood(for child: Child) -> MoodLevel? {
        child.observations
            .sorted { $0.timestamp > $1.timestamp }
            .first?.mood
    }

    func totalFluidToday(for child: Child) -> Int {
        todayMeals(for: child).reduce(0) { $0 + $1.fluidMl }
    }

    func totalSleepMinutesToday(for child: Child) -> Int {
        todayObservations(for: child)
            .compactMap(\.sleepDurationMinutes)
            .reduce(0, +)
    }

    // MARK: - Milestone progress

    func milestoneProgress(for child: Child) -> Double {
        let milestones = child.milestones
        guard !milestones.isEmpty else { return 0 }
        let achieved = milestones.filter { $0.status == .achieved }.count
        return Double(achieved) / Double(milestones.count)
    }

    // MARK: - Recent incidents

    func openIncidents(for child: Child) -> [Incident] {
        child.incidents
            .filter { $0.reviewStatus != .countersigned }
            .sorted { $0.timestamp > $1.timestamp }
    }
}
