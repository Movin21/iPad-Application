// NurseryConnectApp.swift
// NurseryConnect
// App entry — configures SwiftData container and launches directly into the dashboard.

import SwiftUI
import SwiftData

@main
struct NurseryConnectApp: App {

    /// Single shared ModelContainer for all persistent types.
    let container: ModelContainer = {
        let schema = Schema([
            Child.self,
            DailyLog.self,
            MealRecord.self,
            Incident.self,
            EYFSMilestone.self,
            AttendanceRecord.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("SwiftData container failed to initialise: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootSplitView()
                .modelContainer(container)
        }
    }
}
