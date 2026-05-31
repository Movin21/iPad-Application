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

// Replaces the old stacked-bar model. One entry per EYFS domain,
// showing overall % achieved — colour encodes achievement level.
private struct EYFSDomainProgress: Identifiable {
    let id       = UUID()
    let area:    String
    let achieved: Int
    let total:   Int

    var percent: Double { total > 0 ? Double(achieved) / Double(total) * 100 : 0 }

    var barColor: Color {
        switch percent {
        case 75...:   return Color.ncSuccess
        case 50..<75: return Color.ncAccent
        case 1..<50:  return Color.ncWarning
        default:      return Color.secondary.opacity(0.35)
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
    // Horizontal progress bars (0–100 %) — one per domain.
    // Colour encodes attainment level so the weakest areas are instantly visible.

    private var eyfsChartCard: some View {
        AnalyticsChartCard(
            title:       "EYFS Progress by Domain",
            subtitle:    "Milestones achieved per learning area",
            symbol:      "chart.bar.fill",
            accentColor: Color(hex: "5c5c9a")
        ) {
            VStack(spacing: 8) {
                Chart(eyfsProgressData) { d in
                    BarMark(
                        x: .value("Achieved %", d.percent),
                        y: .value("Domain",     d.area)
                    )
                    .foregroundStyle(d.barColor)
                    .cornerRadius(5)
                    .annotation(position: .trailing, alignment: .leading, spacing: 8) {
                        Text("\(d.achieved)/\(d.total)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color.ncOnSurfaceVariant)
                            .monospacedDigit()
                            .frame(minWidth: 30, alignment: .leading)
                    }
                }
                .chartXScale(domain: 0.0...100.0)
                .chartXAxis {
                    AxisMarks(values: [0, 25, 50, 75, 100]) { v in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        AxisValueLabel {
                            if let pct = v.as(Double.self) {
                                Text("\(Int(pct))%").font(.caption2)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in AxisValueLabel().font(.caption2) }
                }
                .frame(height: 220)

                // Colour legend
                HStack(spacing: 14) {
                    eyfsLegendDot(color: .ncSuccess,              label: "≥75 % achieved")
                    eyfsLegendDot(color: .ncAccent,               label: "50–75 %")
                    eyfsLegendDot(color: .ncWarning,              label: "<50 %")
                    eyfsLegendDot(color: .secondary.opacity(0.4), label: "No data")
                }
                .padding(.top, 2)
            }
        }
    }

    private func eyfsLegendDot(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
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
