// Views/Analytics/ChildAnalyticsDashboardView.swift
// NurseryConnect
// Executive analytics dashboard — Apple Charts framework.
// Displays: weekly sleep duration, EYFS milestone breakdown per domain,
// and 7-day fluid intake trend for a selected child.
// Embedded directly into ChildDetailView's scroll content.

import SwiftUI
import Charts

// MARK: - Short EYFSArea labels (file-private)

private extension EYFSArea {
    var shortLabel: String {
        switch self {
        case .communication:  return "C&L"
        case .physical:       return "PD"
        case .personalSocial: return "PSED"
        case .literacy:       return "Literacy"
        case .mathematics:    return "Maths"
        case .understanding:  return "UW"
        case .expressive:     return "EAD"
        }
    }
}

// MARK: - Chart data models

private struct SleepEntry: Identifiable {
    let id    = UUID()
    let date:  Date
    let hours: Double
}

// One entry per EYFS domain.
// levelLabel drives chartForegroundStyleScale — the correct Swift Charts API
// for per-bar colour (direct `.foregroundStyle(color)` is overridden by the
// chart's default palette; `foregroundStyle(by:)` + scale is not).
private struct EYFSDomainProgress: Identifiable {
    let id        = UUID()
    let area:     String
    let achieved: Int
    let total:    Int

    var percent: Double { total > 0 ? Double(achieved) / Double(total) * 100 : 0 }

    var levelLabel: String {
        switch percent {
        case 75...:   return "Strong"
        case 50..<75: return "Good"
        case 1..<50:  return "Developing"
        default:      return "Not Started"
        }
    }
}

private struct FluidEntry: Identifiable {
    let id      = UUID()
    let date:    Date
    let totalMl: Int
}

// MARK: - Main View

struct ChildAnalyticsDashboardView: View {
    let child: Child

    // Toggle between bar chart (by domain) and donut pie (by status)
    @State private var eyfsViewMode: EYFSViewMode = .byDomain

    private enum EYFSViewMode: String, CaseIterable {
        case byDomain  = "By Domain"
        case statusPie = "Status Pie"
    }

    // MARK: Computed chart data

    private var sleepData: [SleepEntry] {
        let cal   = Calendar.current
        let today = Date()
        return (0..<7).reversed().map { offset in
            let day   = cal.date(byAdding: .day, value: -offset, to: today)!
            let start = cal.startOfDay(for: day)
            let end   = cal.date(byAdding: .day, value: 1, to: start)!
            let mins  = child.observations
                .filter { $0.timestamp >= start && $0.timestamp < end && $0.hasSleepRecord }
                .compactMap(\.sleepDurationMinutes)
                .reduce(0, +)
            return SleepEntry(date: start, hours: Double(mins) / 60.0)
        }
    }

    // One entry per domain: total milestones vs how many are "Achieved".
    private var eyfsProgressData: [EYFSDomainProgress] {
        EYFSArea.allCases.map { area in
            let ms = child.milestones.filter { $0.eyfsArea == area }
            return EYFSDomainProgress(
                area:     area.shortLabel,
                achieved: ms.filter { $0.status == .achieved }.count,
                total:    ms.count
            )
        }
    }

    // One entry per MilestoneStatus for the donut chart.
    private struct MilestoneStatusEntry: Identifiable {
        let id    = UUID()
        let status: MilestoneStatus
        let count:  Int
    }

    private var milestoneStatusData: [MilestoneStatusEntry] {
        MilestoneStatus.allCases.compactMap { status in
            let n = child.milestones.filter { $0.status == status }.count
            return n > 0 ? MilestoneStatusEntry(status: status, count: n) : nil
        }
    }

    private var fluidData: [FluidEntry] {
        let cal   = Calendar.current
        let today = Date()
        return (0..<7).reversed().map { offset in
            let day   = cal.date(byAdding: .day, value: -offset, to: today)!
            let start = cal.startOfDay(for: day)
            let end   = cal.date(byAdding: .day, value: 1, to: start)!
            let total = child.mealRecords
                .filter { $0.timestamp >= start && $0.timestamp < end }
                .reduce(0) { $0 + $1.fluidMl }
            return FluidEntry(date: start, totalMl: total)
        }
    }

    // MARK: Body

    var body: some View {
        VStack(spacing: 16) {
            sleepChartCard
            eyfsChartCard
            fluidChartCard
        }
    }

    // MARK: - Sleep Chart Card

    private var sleepChartCard: some View {
        let data    = sleepData
        let maxHrs  = max(data.map(\.hours).max() ?? 0, 4.0)

        return AnalyticsChartCard(
            title:       "Sleep Duration",
            subtitle:    "Last 7 days · hours per day",
            symbol:      "moon.zzz.fill",
            accentColor: Color.ncAccent
        ) {
            Chart(data) { entry in
                BarMark(
                    x: .value("Day",   entry.date,  unit: .day),
                    y: .value("Hours", entry.hours)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.ncAccent, Color.ncPrimaryDim],
                        startPoint: .top,
                        endPoint:   .bottom
                    )
                )
                .cornerRadius(5)

                // Recommended sleep reference line (EYFS guidance: 11–12 h for 1–3 y)
                RuleMark(y: .value("Target", 11.0))
                    .foregroundStyle(Color.ncWarning.opacity(0.65))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("11h target")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(Color.ncWarning)
                            .padding(.trailing, 2)
                    }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                        .font(.caption2)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .stride(by: 2)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    AxisValueLabel {
                        if let h = value.as(Double.self) {
                            Text("\(Int(h))h").font(.caption2)
                        }
                    }
                }
            }
            .chartYScale(domain: 0...max(maxHrs + 1.5, 13))
            .frame(height: 185)
        }
    }

    // MARK: - EYFS Progress Chart Card
    // Segmented control lets the keyworker switch between:
    //   • By Domain  — vertical BarMark, % achieved per EYFS area
    //   • Status Pie — SectorMark donut, all milestones by status

    private var eyfsChartCard: some View {
        AnalyticsChartCard(
            title:       "EYFS Progress",
            subtitle:    "Milestones · tap chart type to switch view",
            symbol:      "chart.bar.fill",
            accentColor: Color(hex: "5c5c9a")
        ) {
            VStack(spacing: 12) {
                // Mode selector
                Picker("Chart type", selection: $eyfsViewMode) {
                    ForEach(EYFSViewMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                if eyfsViewMode == .byDomain {
                    eyfsDomainBarContent
                } else {
                    eyfsDonutContent
                }
            }
        }
    }

    // MARK: Domain bar chart (existing)

    private var eyfsDomainBarContent: some View {
        VStack(spacing: 10) {
            Chart(eyfsProgressData) { d in
                BarMark(
                    x: .value("Domain",     d.area),
                    y: .value("Achieved %", d.percent)
                )
                .foregroundStyle(by: .value("Level", d.levelLabel))
                .cornerRadius(6)
                .annotation(position: .top, alignment: .center, spacing: 4) {
                    Text("\(d.achieved)/\(d.total)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.ncOnSurfaceVariant)
                        .monospacedDigit()
                }

                RuleMark(y: .value("Target", 75.0))
                    .foregroundStyle(Color.ncSuccess.opacity(0.55))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                    .annotation(position: .top, alignment: .trailing, spacing: 2) {
                        Text("75% target")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(Color.ncSuccess.opacity(0.75))
                    }
            }
            .chartForegroundStyleScale([
                "Strong":      Color.ncSuccess,
                "Good":        Color.ncAccent,
                "Developing":  Color.ncWarning,
                "Not Started": Color.secondary.opacity(0.28),
            ])
            .chartLegend(.hidden)
            .chartYScale(domain: 0.0...100.0)
            .chartYAxis {
                AxisMarks(values: [0, 25, 50, 75, 100]) { v in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    AxisValueLabel {
                        if let p = v.as(Double.self) {
                            Text("\(Int(p))%").font(.caption2)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { _ in AxisValueLabel().font(.caption2) }
            }
            .frame(height: 210)

            HStack(spacing: 14) {
                eyfsLegendDot(color: .ncSuccess,               label: "Strong ≥75%")
                eyfsLegendDot(color: .ncAccent,                label: "Good 50–75%")
                eyfsLegendDot(color: .ncWarning,               label: "Developing")
                eyfsLegendDot(color: .secondary.opacity(0.35), label: "Not started")
            }
            .padding(.top, 2)
        }
    }

    // MARK: Status donut / pie chart (new)

    private var eyfsDonutContent: some View {
        let total    = child.milestones.count
        let achieved = child.milestones.filter { $0.status == .achieved }.count

        return VStack(spacing: 12) {
            if milestoneStatusData.isEmpty {
                ContentUnavailableView(
                    "No Milestones",
                    systemImage: "chart.pie",
                    description: Text("Assign EYFS milestones to see the status breakdown.")
                )
                .frame(height: 200)
            } else {
                Chart(milestoneStatusData) { entry in
                    SectorMark(
                        angle:        .value("Milestones", entry.count),
                        innerRadius:  .ratio(0.54),
                        angularInset: 2.5
                    )
                    .foregroundStyle(by: .value("Status", entry.status.rawValue))
                    .cornerRadius(5)
                    .annotation(position: .overlay) {
                        if entry.count > 0 {
                            Text("\(entry.count)")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .chartForegroundStyleScale([
                    MilestoneStatus.notStarted.rawValue: Color.secondary.opacity(0.35),
                    MilestoneStatus.emerging.rawValue:   Color.ncWarning,
                    MilestoneStatus.developing.rawValue: Color.ncAccent,
                    MilestoneStatus.achieved.rawValue:   Color.ncSuccess,
                ])
                .chartLegend(position: .trailing, alignment: .center, spacing: 16)
                .frame(height: 220)
                .overlay {
                    // Centre label inside the donut hole
                    VStack(spacing: 1) {
                        Text("\(achieved)")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(Color.ncSuccess)
                        Text("of \(total)")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.ncOnSurfaceVariant)
                        Text("achieved")
                            .font(.caption2)
                            .foregroundStyle(Color.ncOnSurfaceVariant)
                    }
                }
            }

            // Overall progress bar
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Overall Achievement")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.ncOnSurfaceVariant)
                    Spacer()
                    Text(total > 0 ? "\(Int(Double(achieved)/Double(total)*100))%" : "0%")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.ncSuccess)
                        .monospacedDigit()
                }
                ProgressView(value: total > 0 ? Double(achieved)/Double(total) : 0)
                    .tint(Color.ncSuccess)
            }
            .padding(.top, 2)
        }
    }

    private func eyfsLegendDot(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(.caption2)
                .foregroundStyle(Color.ncOnSurfaceVariant)
        }
    }

    // MARK: - Fluid Intake Chart Card

    private var fluidChartCard: some View {
        let data   = fluidData
        let maxMl  = Double(max(data.map(\.totalMl).max() ?? 0, 300))

        return AnalyticsChartCard(
            title:       "Fluid Intake",
            subtitle:    "Last 7 days · total millilitres",
            symbol:      "drop.fill",
            accentColor: Color.ncSecondary
        ) {
            Chart(data) { entry in
                AreaMark(
                    x: .value("Day",  entry.date,    unit: .day),
                    y: .value("Fluid (ml)", entry.totalMl)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color.ncSecondary.opacity(0.38),
                            Color.ncSecondary.opacity(0.04),
                        ],
                        startPoint: .top,
                        endPoint:   .bottom
                    )
                )
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("Day",  entry.date,    unit: .day),
                    y: .value("Fluid (ml)", entry.totalMl)
                )
                .foregroundStyle(Color.ncSecondary)
                .lineStyle(StrokeStyle(lineWidth: 2.5))
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Day",  entry.date,    unit: .day),
                    y: .value("Fluid (ml)", entry.totalMl)
                )
                .foregroundStyle(Color.ncSecondary)
                .symbolSize(38)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                        .font(.caption2)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .stride(by: 100)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    AxisValueLabel {
                        if let ml = value.as(Int.self) {
                            Text("\(ml)ml").font(.caption2)
                        }
                    }
                }
            }
            .chartYScale(domain: 0...max(maxMl + 60, 500))
            .frame(height: 155)
        }
    }
}

// MARK: - Chart Card Container

struct AnalyticsChartCard<Content: View>: View {
    let title:       String
    let subtitle:    String
    let symbol:      String
    let accentColor: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(accentColor.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: symbol)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(accentColor)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.ncOnSurface)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(Color.ncOnSurfaceVariant)
                }
                Spacer()
            }

            content()
        }
        .padding(16)
        .background(Color.ncCardBg, in: RoundedRectangle(cornerRadius: NCRadius.card))
        .ncCardShadow()
    }
}
