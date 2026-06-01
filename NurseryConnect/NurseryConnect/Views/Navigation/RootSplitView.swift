// Views/Navigation/RootSplitView.swift
// NurseryConnect
// iPadOS root: 3-column NavigationSplitView.
// Sidebar (branding/stats) → Child list (middle) → Child detail dashboard (trailing).
// Collapses gracefully to a NavigationStack on compact-width (iPhone) automatically.

import SwiftUI
import SwiftData

// MARK: - Root Split View

struct RootSplitView: View {
    @Environment(\.modelContext) private var context
    @Query private var allChildren: [Child]

    @State private var vm              = DashboardViewModel()
    @State private var selectedChild: Child?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var appeared        = false

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {

            // ── Column 1: Sidebar ─────────────────────────────────────
            SidebarPanelView(allChildren: allChildren)

        } content: {

            // ── Column 2: Child selection list ────────────────────────
            ChildSelectionListView(
                allChildren: allChildren,
                selectedChild: $selectedChild
            )

        } detail: {

            // ── Column 3: Detail dashboard ────────────────────────────
            if let child = selectedChild {
                ChildDetailView(child: child)
                    .id(child.id)   // force fresh VM when switching children
            } else {
                RoomOverviewDetailView(allChildren: allChildren)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .tint(Color.ncAccent)
        .onAppear {
            guard !appeared else { return }
            vm.seedSampleDataIfNeeded(context: context)
            appeared = true
        }
    }
}

// MARK: - Column 1: Sidebar Panel

private struct SidebarPanelView: View {
    let allChildren: [Child]

    private var mine: [Child] {
        allChildren.filter { $0.assignedKeyworkerName == kKeyworkerName }
    }

    private var todayObs: Int {
        let today = Calendar.current.startOfDay(for: Date())
        return mine.flatMap(\.observations).filter { $0.timestamp >= today }.count
    }

    private var pendingIncidents: Int {
        mine.flatMap(\.incidents).filter { $0.reviewStatus == .pendingReview }.count
    }

    private var alertCount: Int {
        mine.filter(\.hasActiveAlerts).count
    }

    private var presentTodayCount: Int {
        let today = Calendar.current.startOfDay(for: Date())
        return mine.filter { child in
            child.attendanceRecords.contains {
                Calendar.current.isDate($0.date, inSameDayAs: today) && $0.status == .present
            }
        }.count
    }

    var body: some View {
        List {
            // ── Keyworker identity card ──────────────────────────────
            Section {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.ncAccent.opacity(0.14))
                            .frame(width: 50, height: 50)
                        Text(kKeyworkerName
                            .components(separatedBy: " ")
                            .compactMap(\.first)
                            .prefix(2)
                            .map(String.init)
                            .joined())
                            .font(.headline.weight(.bold))
                            .foregroundStyle(Color.ncAccent)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(kKeyworkerName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.ncOnSurface)
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.shield.fill")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Color.ncSuccess)
                            Text("Keyworker · Active")
                                .font(.caption)
                                .foregroundStyle(Color.ncOnSurfaceVariant)
                        }
                    }
                    Spacer()
                }
                .padding(.vertical, 6)
                .listRowBackground(Color.ncAccent.opacity(0.05))
            }

            // ── Navigation marker ────────────────────────────────────
            Section("My Room") {
                Label {
                    Text("My Children")
                        .font(.subheadline.weight(.semibold))
                } icon: {
                    Image(systemName: "figure.and.child.holdinghands")
                        .foregroundStyle(Color.ncAccent)
                }
                .padding(.vertical, 2)
            }

            // ── Live stats ───────────────────────────────────────────
            Section("Today's Summary") {
                SidebarStatRow(
                    label: "Key Children",
                    value: "\(mine.count)",
                    symbol: "person.3.fill",
                    color: Color.ncAccent
                )
                SidebarStatRow(
                    label: "Observations",
                    value: "\(todayObs)",
                    symbol: "pencil.and.list.clipboard",
                    color: Color.ncSecondary
                )
                SidebarStatRow(
                    label: "Medical Alerts",
                    value: "\(alertCount)",
                    symbol: "cross.circle.fill",
                    color: alertCount > 0 ? Color.ncAlert : Color.ncOnSurfaceVariant
                )
                SidebarStatRow(
                    label: "Pending Incidents",
                    value: "\(pendingIncidents)",
                    symbol: "exclamationmark.triangle.fill",
                    color: pendingIncidents > 0 ? Color.ncWarning : Color.ncOnSurfaceVariant
                )
                SidebarStatRow(
                    label: "Present Today",
                    value: "\(presentTodayCount)/\(mine.count)",
                    symbol: "person.fill.checkmark",
                    color: presentTodayCount > 0 ? Color.ncSuccess : Color.ncOnSurfaceVariant
                )
            }

            // ── Shift date ───────────────────────────────────────────
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(Date().formatted(.dateTime.weekday(.wide).day().month(.wide).year()))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.ncOnSurface)
                    Text("Early shift — NurseryConnect")
                        .font(.caption2)
                        .foregroundStyle(Color.ncOnSurfaceVariant)
                }
                .padding(.vertical, 4)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("NurseryConnect")
        .navigationSplitViewColumnWidth(min: 200, ideal: 252, max: 295)
        .safeAreaInset(edge: .top, spacing: 0) {
            // Logo header pinned above the list
            VStack(spacing: 0) {
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 54)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                Divider()
            }
            .background(.ultraThinMaterial)
        }
    }
}

// MARK: - Column 2: Child Selection List

private struct ChildSelectionListView: View {
    let allChildren: [Child]
    @Binding var selectedChild: Child?

    @State private var searchText      = ""
    @State private var showingAddChild = false

    private var children: [Child] {
        let mine = allChildren.filter { $0.assignedKeyworkerName == kKeyworkerName }
        guard !searchText.isEmpty else { return mine }
        return mine.filter { $0.fullName.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        List(selection: $selectedChild) {
            ForEach(children) { child in
                ChildCardView(child: child)
                    .tag(child)
                    .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .background(Color.ncBg)
        .navigationTitle("My Children")
        .navigationSplitViewColumnWidth(min: 280, ideal: 345, max: 430)
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search children…"
        )
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    HapticFeedback.medium()
                    showingAddChild = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.ncAccent)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
        .sheet(isPresented: $showingAddChild) { AddChildView() }
        .overlay {
            if children.isEmpty { emptyState }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3.sequence")
                .font(.system(size: 46))
                .foregroundStyle(Color.ncAccent.opacity(0.38))
            Text("No Children Assigned")
                .font(.headline)
                .foregroundStyle(Color.ncOnSurface)
            Text("Tap + to register a child to your key group")
                .font(.subheadline)
                .foregroundStyle(Color.ncOnSurfaceVariant)
                .multilineTextAlignment(.center)
        }
        .padding(32)
    }
}

// MARK: - Column 3: Room Overview (no child selected)

private struct RoomOverviewDetailView: View {
    let allChildren: [Child]

    private var mine: [Child] {
        allChildren.filter { $0.assignedKeyworkerName == kKeyworkerName }
    }

    private var todayObs: Int {
        let today = Calendar.current.startOfDay(for: Date())
        return mine.flatMap(\.observations).filter { $0.timestamp >= today }.count
    }

    private var pendingIncidents: Int {
        mine.flatMap(\.incidents).filter { $0.reviewStatus == .pendingReview }.count
    }

    private var presentTodayCount: Int {
        let today = Calendar.current.startOfDay(for: Date())
        return mine.filter { child in
            child.attendanceRecords.contains {
                Calendar.current.isDate($0.date, inSameDayAs: today) && $0.status == .present
            }
        }.count
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12:  return "Good morning"
        case 12..<17: return "Good afternoon"
        default:      return "Good evening"
        }
    }

    var body: some View {
        ZStack {
            Color.ncBg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {

                    // Hero gradient card
                    heroCard
                        .padding(.horizontal, 32)
                        .padding(.top, 32)

                    // Stats grid
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 4),
                        spacing: 14
                    ) {
                        RoomStatCard(
                            value: "\(mine.count)",
                            label: "Key Children",
                            symbol: "figure.and.child.holdinghands",
                            color: Color.ncAccent
                        )
                        RoomStatCard(
                            value: "\(todayObs)",
                            label: "Obs. Today",
                            symbol: "pencil.and.list.clipboard",
                            color: Color.ncSecondary
                        )
                        RoomStatCard(
                            value: "\(mine.filter(\.hasActiveAlerts).count)",
                            label: "Medical Alerts",
                            symbol: "cross.circle.fill",
                            color: mine.filter(\.hasActiveAlerts).count > 0
                                ? Color.ncAlert
                                : Color.ncOnSurfaceVariant
                        )
                        RoomStatCard(
                            value: "\(pendingIncidents)",
                            label: "Pending Incidents",
                            symbol: "exclamationmark.triangle.fill",
                            color: pendingIncidents > 0
                                ? Color.ncWarning
                                : Color.ncOnSurfaceVariant
                        )
                        RoomStatCard(
                            value: "\(presentTodayCount)/\(mine.count)",
                            label: "Present Today",
                            symbol: "person.fill.checkmark",
                            color: presentTodayCount > 0
                                ? Color.ncSuccess
                                : Color.ncOnSurfaceVariant
                        )
                    }
                    .padding(.horizontal, 32)

                    // Prompt
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.left.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color.ncAccent.opacity(0.45))
                        Text("Select a child from the list to open their profile and analytics dashboard")
                            .font(.subheadline)
                            .foregroundStyle(Color.ncOnSurfaceVariant)
                    }
                    .padding(.horizontal, 32)
                    .padding(.top, 4)
                }
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Room Dashboard")
        .navigationBarTitleDisplayMode(.large)
    }

    private var heroCard: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient.ncPrimaryCTA
                .clipShape(RoundedRectangle(cornerRadius: 20))
            // Decorative circles
            Circle()
                .fill(.white.opacity(0.055))
                .frame(width: 200)
                .blur(radius: 2)
                .offset(x: 380, y: -24)
            Circle()
                .fill(.white.opacity(0.035))
                .frame(width: 100)
                .offset(x: 480, y: 30)
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.80))
                Text(kKeyworkerName.components(separatedBy: " ").first ?? "Keyworker")
                    .font(.title.weight(.bold))
                    .foregroundStyle(.white)
                Text(Date().formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 136)
        .ncGlassShadow()
    }
}

// MARK: - Shared sub-components

private struct SidebarStatRow: View {
    let label: String
    let value: String
    let symbol: String
    let color: Color

    var body: some View {
        HStack {
            Label(label, systemImage: symbol)
                .foregroundStyle(color)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.ncOnSurface)
                .monospacedDigit()
        }
    }
}

private struct RoomStatCard: View {
    let value: String
    let label: String
    let symbol: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol)
                .font(.title2.weight(.semibold))
                .foregroundStyle(color)
            Text(value)
                .font(.title.weight(.bold))
                .foregroundStyle(Color.ncOnSurface)
                .monospacedDigit()
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(color.opacity(0.85))
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(color.opacity(0.09), in: RoundedRectangle(cornerRadius: NCRadius.card))
    }
}
