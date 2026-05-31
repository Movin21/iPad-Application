// Views/ChildDetail/ChildDetailView.swift
// NurseryConnect
// Full profile + today's summary for a single child.
// NavigationStack second-level screen.

import SwiftUI
import SwiftData

struct ChildDetailView: View {
    let child: Child
    @State private var vm = ChildDetailViewModel()

    /// Deterministic avatar colour matching ChildCardView
    private var avatarColor: Color {
        let palette: [Color] = [
            Color(hex: "2a6677"),
            Color(hex: "3b6850"),
            Color(hex: "5c5c9a"),
            Color(hex: "9a5c5c"),
            Color(hex: "7a6a3a"),
            Color(hex: "3a6a7a"),
            Color(hex: "6a3a7a"),
        ]
        let index = abs(child.fullName.hashValue) % palette.count
        return palette[index]
    }

    var body: some View {
        ZStack {
            Color.ncBg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    // Profile header card
                    profileHeader
                        .padding(.horizontal, 16)
                        .padding(.top, 10)

                    // Alert banner — only appears if child has alerts
                    AlertBannerView(child: child)
                        .padding(.horizontal, 16)
                        .transition(.move(edge: .top).combined(with: .opacity))

                    // Quick action buttons
                    quickActionsGrid
                        .padding(.horizontal, 16)

                    // Today at a glance
                    todaySection
                        .padding(.horizontal, 16)

                    // Recent observations
                    if !vm.todayObservations(for: child).isEmpty {
                        recentObservationsSection
                            .padding(.horizontal, 16)
                    }

                    // Today's meals
                    if !vm.todayMeals(for: child).isEmpty {
                        mealRecordsSection
                            .padding(.horizontal, 16)
                    }

                    // EYFS progress card
                    eyfsProgressCard
                        .padding(.horizontal, 16)

                    // Analytics — weekly trends via Charts framework
                    weeklyTrendsSection
                        .padding(.horizontal, 16)

                    // Open incidents
                    if !vm.openIncidents(for: child).isEmpty {
                        incidentsSection
                            .padding(.horizontal, 16)
                    }
                }
                .padding(.bottom, 32)
            }
        }
        .navigationTitle(child.firstName)
        .navigationBarTitleDisplayMode(.inline)
        .tint(Color.ncAccent)
        .sheet(isPresented: $vm.showingLogForm) {
            LogFormView(child: child)
        }
        .sheet(isPresented: $vm.showingMealLog) {
            MealLogView(child: child)
        }
        .sheet(isPresented: $vm.showingIncidentForm) {
            IncidentFormView(child: child)
        }
        .sheet(isPresented: $vm.showingEYFSTracker) {
            EYFSTrackerView(child: child)
        }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        HStack(spacing: 16) {
            // Avatar
            ZStack {
                Circle()
                    .fill(avatarColor.opacity(0.15))
                    .frame(width: 64, height: 64)
                Circle()
                    .strokeBorder(avatarColor.opacity(0.25), lineWidth: 1.5)
                    .frame(width: 64, height: 64)
                Text(child.firstName.prefix(1) + child.lastName.prefix(1))
                    .font(.title2.weight(.bold))
                    .foregroundStyle(avatarColor)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(child.fullName)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.ncOnSurface)

                // Age — years, months, days auto-calculated
                Text(child.ageDescription)
                    .font(.subheadline)
                    .foregroundStyle(Color.ncOnSurfaceVariant)

                // Birthday row
                HStack(spacing: 5) {
                    Image(systemName: child.isBirthdayToday ? "birthday.cake.fill" : "calendar")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(child.isBirthdayToday ? Color(hex: "c57c2a") : Color.ncOnSurfaceVariant)
                    Text(child.birthdayFormatted)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(child.isBirthdayToday ? Color(hex: "c57c2a") : Color.ncOnSurfaceVariant)
                    if child.isBirthdayToday {
                        Text("Happy Birthday!")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color(hex: "c57c2a"))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(hex: "c57c2a").opacity(0.12), in: Capsule())
                    }
                }

                if child.hasActiveAlerts {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2.weight(.bold))
                        Text(child.allergies.isEmpty
                             ? "Medical Alert"
                             : child.allergies.joined(separator: ", "))
                            .font(.caption2.weight(.semibold))
                            .lineLimit(1)
                    }
                    .foregroundStyle(Color.ncAlert)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.ncAlert.opacity(0.10), in: Capsule())
                }
            }

            Spacer()
        }
        .padding(16)
        .background(Color.ncCardBg, in: RoundedRectangle(cornerRadius: NCRadius.card))
        .ncCardShadow()
    }

    // MARK: - Quick Actions
    // Uses eager Grid (not LazyVGrid) so cells are never deallocated during
    // scroll — LazyVGrid can restore recycled views at zero opacity.

    private var quickActionsGrid: some View {
        Grid(horizontalSpacing: 10, verticalSpacing: 10) {
            GridRow {
                ActionButtonView(title: "Log Observation", symbol: "pencil.and.list.clipboard", color: Color.ncAccent) {
                    HapticFeedback.medium()
                    vm.showingLogForm = true
                }
                ActionButtonView(title: "Record Meal", symbol: "fork.knife", color: Color.ncSuccess) {
                    HapticFeedback.medium()
                    vm.showingMealLog = true
                }
            }
            GridRow {
                ActionButtonView(title: "Report Incident", symbol: "bandage.fill", color: Color.ncAlert) {
                    HapticFeedback.medium()
                    vm.showingIncidentForm = true
                }
                ActionButtonView(title: "EYFS Progress", symbol: "chart.bar.fill", color: Color(hex: "5c5c9a")) {
                    HapticFeedback.medium()
                    vm.showingEYFSTracker = true
                }
            }
        }
    }

    // MARK: - Today at a Glance

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Today at a Glance")

            HStack(spacing: 10) {
                moodGlanceTile(
                    mood: vm.latestMood(for: child),
                    label: "Latest Mood",
                    bg: Color.ncCardBg
                )
                glanceTile(
                    value: "\(vm.totalFluidToday(for: child))ml",
                    label: "Fluid Intake",
                    bg: Color.ncCardBg
                )
                glanceTile(
                    value: sleepLabel,
                    label: "Sleep Today",
                    bg: Color.ncCardBg
                )
                glanceTile(
                    value: "\(vm.todayMeals(for: child).count)",
                    label: "Meals Logged",
                    bg: Color.ncCardBg
                )
            }
        }
    }

    private var sleepLabel: String {
        let mins = vm.totalSleepMinutesToday(for: child)
        guard mins > 0 else { return "—" }
        let h = mins / 60, m = mins % 60
        return h > 0 ? "\(h)h\(m)m" : "\(m)m"
    }

    private func moodGlanceTile(mood: MoodLevel?, label: String, bg: Color) -> some View {
        VStack(spacing: 3) {
            if let mood = mood {
                MoodIconView(mood: mood, size: 30)
            } else {
                Image(systemName: "moon.zzz.fill")
                    .font(.title3)
                    .foregroundStyle(Color.ncOnSurfaceVariant.opacity(0.4))
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(Color.ncOnSurfaceVariant)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(bg, in: RoundedRectangle(cornerRadius: NCRadius.badge))
        .ncSubtleShadow()
    }

    private func glanceTile(value: String, label: String, bg: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(Color.ncOnSurface)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label)
                .font(.caption2)
                .foregroundStyle(Color.ncOnSurfaceVariant)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(bg, in: RoundedRectangle(cornerRadius: NCRadius.badge))
        .ncSubtleShadow()
    }

    // MARK: - Recent Observations

    private var recentObservationsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Today's Observations")

            ForEach(vm.todayObservations(for: child).prefix(3)) { obs in
                ObservationRowView(observation: obs)
            }
        }
    }

    // MARK: - Meal Records

    private var mealRecordsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Today's Meals")
            ForEach(vm.todayMeals(for: child).prefix(5)) { meal in
                MealRecordRowView(meal: meal)
            }
        }
    }

    // MARK: - EYFS Progress

    private var eyfsProgressCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("EYFS Progress")

            let progress = vm.milestoneProgress(for: child)
            let achieved = child.milestones.filter { $0.status == .achieved }.count

            HStack(spacing: 14) {
                ProgressCircle(progress: progress)

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(achieved) / \(child.milestones.count) Milestones Achieved")
                        .font(.subheadline.weight(.semibold))
                    ProgressView(value: progress)
                        .tint(Color.ncSuccess)
                    Button("View All Milestones →") {
                        HapticFeedback.light()
                        vm.showingEYFSTracker = true
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.ncAccent)
                }
            }
            .padding(14)
            .background(Color.ncCardBg, in: RoundedRectangle(cornerRadius: NCRadius.card))
            .ncCardShadow()
        }
    }

    // MARK: - Weekly Trends (Charts)

    private var weeklyTrendsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Weekly Trends")
            ChildAnalyticsDashboardView(child: child)
        }
    }

    // MARK: - Open Incidents

    private var incidentsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Incidents Pending Review")

            ForEach(vm.openIncidents(for: child)) { incident in
                IncidentRowView(incident: incident)
            }
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        HStack(spacing: 8) {
            Capsule()
                .fill(Color.ncAccent)
                .frame(width: 3, height: 14)
            Text(title.uppercased())
                .font(NCFont.sectionHeader())
                .foregroundStyle(Color.ncAccent)
            Spacer()
        }
    }
}

// MARK: - Action Button

struct ActionButtonView: View {
    let title: String
    let symbol: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                // Icon circle — solid tinted background
                ZStack {
                    Circle()
                        .fill(color)
                        .frame(width: 50, height: 50)
                    Image(systemName: symbol)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                }

                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(color)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: NCRadius.card))
            .overlay(
                RoundedRectangle(cornerRadius: NCRadius.card)
                    .strokeBorder(color.opacity(0.22), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Observation Row

struct ObservationRowView: View {
    let observation: DailyLog

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: observation.eyfsArea.sfSymbol)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.ncAccent)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(observation.eyfsArea.rawValue)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.ncOnSurfaceVariant)
                Text(observation.activityDescription.isEmpty
                     ? "Observation logged"
                     : observation.activityDescription)
                    .font(.subheadline)
                    .foregroundStyle(Color.ncOnSurface)
                    .lineLimit(2)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                MoodIconView(mood: observation.mood, size: 26)
                Text(observation.timestamp.shortTime)
                    .font(.caption2)
                    .foregroundStyle(Color.ncOnSurfaceVariant)
            }
        }
        .padding(12)
        .background(Color.ncCardBg, in: RoundedRectangle(cornerRadius: NCRadius.badge))
        .ncSubtleShadow()
    }
}

// MARK: - Incident Row

struct IncidentRowView: View {
    let incident: Incident

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: incident.reviewStatus.sfSymbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(incident.reviewStatus.color))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(incident.title.isEmpty ? incident.incidentType.rawValue : incident.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.ncOnSurface)
                Text(incident.timestamp.shortDate)
                    .font(.caption)
                    .foregroundStyle(Color.ncOnSurfaceVariant)
            }

            Spacer()

            Text(incident.reviewStatus.rawValue)
                .font(.caption.weight(.medium))
                .foregroundStyle(Color(incident.reviewStatus.color))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(incident.reviewStatus.color).opacity(0.12), in: Capsule())
        }
        .padding(12)
        .background(Color.ncCardBg, in: RoundedRectangle(cornerRadius: NCRadius.badge))
        .ncSubtleShadow()
    }
}

// MARK: - Meal Record Row

struct MealRecordRowView: View {
    let meal: MealRecord

    private var mealIcon: String {
        switch meal.mealType {
        case .breakfast:      return "sun.horizon.fill"
        case .midMorningSnack: return "cup.and.saucer.fill"
        case .lunch:          return "fork.knife"
        case .afternoonSnack: return "leaf.fill"
        case .tea:            return "moon.stars.fill"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: mealIcon)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.ncSuccess)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(meal.mealType.rawValue)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.ncOnSurfaceVariant)
                Text(meal.foodOffered.isEmpty ? "Meal recorded" : meal.foodOffered)
                    .font(.subheadline)
                    .foregroundStyle(Color.ncOnSurface)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(meal.foodConsumed.rawValue)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.ncAccent)
                Text(meal.timestamp.shortTime)
                    .font(.caption2)
                    .foregroundStyle(Color.ncOnSurfaceVariant)
            }
        }
        .padding(12)
        .background(Color.ncCardBg, in: RoundedRectangle(cornerRadius: NCRadius.badge))
        .ncSubtleShadow()
    }
}

// MARK: - Progress Circle

struct ProgressCircle: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: 5)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.ncSuccess, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.6), value: progress)
            Text("\(Int(progress * 100))%")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.ncOnSurface)
        }
        .frame(width: 56, height: 56)
    }
}
