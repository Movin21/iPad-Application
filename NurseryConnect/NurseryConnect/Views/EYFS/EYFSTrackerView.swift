// Views/EYFS/EYFSTrackerView.swift
// NurseryConnect
// EYFS 2024 developmental milestone tracker — grouped by area,
// with status picker and notes per milestone.

import SwiftUI
import SwiftData

struct EYFSTrackerView: View {
    let child: Child
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var selectedArea: EYFSArea? = nil
    @State private var showingMilestoneEdit: EYFSMilestone? = nil

    private var milestonesByArea: [(EYFSArea, [EYFSMilestone])] {
        let areas = EYFSArea.allCases
        return areas.compactMap { area -> (EYFSArea, [EYFSMilestone])? in
            let list = child.milestones
                .filter { $0.eyfsArea == area }
                .sorted { $0.milestoneDescription < $1.milestoneDescription }
            return list.isEmpty ? nil : (area, list)
        }
    }

    private var filteredMilestones: [(EYFSArea, [EYFSMilestone])] {
        guard let area = selectedArea else { return milestonesByArea }
        return milestonesByArea.filter { $0.0 == area }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Area filter chips
                areaFilter
                    .padding(.vertical, 8)

                // Progress summary
                progressHeader
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)

                // Milestone list
                List {
                    ForEach(filteredMilestones, id: \.0) { area, milestones in
                        Section {
                            ForEach(milestones) { milestone in
                                MilestoneRowView(milestone: milestone) {
                                    showingMilestoneEdit = milestone
                                }
                            }
                        } header: {
                            Label(area.rawValue, systemImage: area.sfSymbol)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.ncAccent)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("EYFS Milestones")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        HapticFeedback.light()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .sheet(item: $showingMilestoneEdit) { milestone in
                MilestoneEditView(milestone: milestone, childName: child.firstName)
            }
        }
        .tint(Color.ncAccent)
    }

    // MARK: - Area Filter

    private var areaFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(label: "All", area: nil)
                ForEach(EYFSArea.allCases, id: \.self) { area in
                    filterChip(label: area.rawValue.components(separatedBy: " ").first ?? "", area: area)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func filterChip(label: String, area: EYFSArea?) -> some View {
        Button {
            withAnimation(.spring(response: 0.3)) { selectedArea = area }
            HapticFeedback.light()
        } label: {
            Text(label)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    selectedArea == area ? Color.ncAccent : Color.ncCardBg,
                    in: Capsule()
                )
                .foregroundStyle(selectedArea == area ? .white : .primary)
                .ncSubtleShadow()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Progress Header

    private var progressHeader: some View {
        let total    = child.milestones.count
        let achieved = child.milestones.filter { $0.status == .achieved }.count
        let develop  = child.milestones.filter { $0.status == .developing }.count
        let emerging = child.milestones.filter { $0.status == .emerging }.count
        let progress = total > 0 ? Double(achieved) / Double(total) : 0

        return HStack(spacing: 12) {
            ProgressCircle(progress: progress)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(achieved)/\(total) Achieved")
                    .font(.subheadline.weight(.semibold))
                HStack(spacing: 8) {
                    statusDot("Developing", count: develop, color: Color(hex: "3a6a9a"))
                    statusDot("Emerging",   count: emerging, color: Color(hex: "c57c2a"))
                }
            }
        }
        .padding(12)
        .background(Color.ncCardBg, in: RoundedRectangle(cornerRadius: NCRadius.card))
        .ncCardShadow()
    }

    private func statusDot(_ label: String, count: Int, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text("\(count) \(label)")
                .font(.caption)
                .foregroundStyle(Color.ncOnSurfaceVariant)
        }
    }
}

// MARK: - Milestone Row

struct MilestoneRowView: View {
    @Bindable var milestone: EYFSMilestone
    let onEdit: () -> Void
    @Environment(\.modelContext) private var context

    private var statusIcon: String {
        switch milestone.status {
        case .notStarted: return "circle"
        case .emerging:   return "circle.dotted"
        case .developing: return "circle.lefthalf.filled"
        case .achieved:   return "checkmark.circle.fill"
        }
    }

    private var statusColor: Color {
        switch milestone.status {
        case .notStarted: return Color.ncOnSurfaceVariant
        case .emerging:   return Color(hex: "c57c2a")
        case .developing: return Color(hex: "3a6a9a")
        case .achieved:   return Color.ncSuccess
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Dropdown menu to set status directly
            Menu {
                ForEach(MilestoneStatus.allCases, id: \.self) { s in
                    Button {
                        setStatus(to: s)
                    } label: {
                        Label(s.rawValue, systemImage: statusIconName(for: s))
                    }
                }
            } label: {
                Image(systemName: statusIcon)
                    .font(.title3)
                    .foregroundStyle(statusColor)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 28)
            }
            .menuOrder(.fixed)

            VStack(alignment: .leading, spacing: 3) {
                Text(milestone.milestoneDescription)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                HStack(spacing: 6) {
                    if !milestone.ageBand.isEmpty {
                        Text(milestone.ageBand)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if milestone.status == .achieved, let date = milestone.achievedDate {
                        Text("✓ \(date.shortDate)")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(Color.ncSuccess)
                    }
                }
            }

            Spacer()

            // Status badge — opens notes editor
            Button(action: onEdit) {
                Text(milestone.status.rawValue)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.12), in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private func setStatus(to newStatus: MilestoneStatus) {
        milestone.status = newStatus
        milestone.achievedDate = (newStatus == .achieved) ? Date() : nil
        milestone.lastUpdated  = Date()
        milestone.keyworkerName = kKeyworkerName
        try? context.save()
        HapticFeedback.light()
    }

    private func statusIconName(for status: MilestoneStatus) -> String {
        switch status {
        case .notStarted: return "circle"
        case .emerging:   return "circle.dotted"
        case .developing: return "circle.lefthalf.filled"
        case .achieved:   return "checkmark.circle.fill"
        }
    }
}

// MARK: - Milestone Edit Sheet

struct MilestoneEditView: View {
    @Bindable var milestone: EYFSMilestone
    let childName: String
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Milestone") {
                    Text(milestone.milestoneDescription)
                        .font(.body)
                    Text(milestone.eyfsArea.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Status") {
                    ForEach(MilestoneStatus.allCases, id: \.self) { s in
                        Button {
                            updateStatus(to: s)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: statusIcon(for: s))
                                    .font(.body)
                                    .foregroundStyle(statusColor(for: s))
                                    .frame(width: 24)
                                Text(s.rawValue)
                                    .foregroundStyle(Color.primary)
                                Spacer()
                                if milestone.status == s {
                                    Image(systemName: "checkmark")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Color.ncAccent)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section("Observation Notes") {
                    TextField("Context, examples, evidence…", text: $milestone.notes, axis: .vertical)
                        .lineLimit(3...8)
                        .onChange(of: milestone.notes) { _, _ in
                            milestone.lastUpdated = Date()
                            try? context.save()
                        }
                }
            }
            .navigationTitle("\(childName)'s Milestone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        HapticFeedback.success()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func updateStatus(to newStatus: MilestoneStatus) {
        milestone.status = newStatus
        milestone.achievedDate = (newStatus == .achieved) ? Date() : nil
        milestone.lastUpdated  = Date()
        milestone.keyworkerName = kKeyworkerName
        try? context.save()
        HapticFeedback.light()
    }

    private func statusIcon(for status: MilestoneStatus) -> String {
        switch status {
        case .notStarted: return "circle"
        case .emerging:   return "circle.dotted"
        case .developing: return "circle.lefthalf.filled"
        case .achieved:   return "checkmark.circle.fill"
        }
    }

    private func statusColor(for status: MilestoneStatus) -> Color {
        switch status {
        case .notStarted: return Color.ncOnSurfaceVariant
        case .emerging:   return Color(hex: "c57c2a")
        case .developing: return Color(hex: "3a6a9a")
        case .achieved:   return Color.ncSuccess
        }
    }
}
