// Views/Dashboard/ChildCardView.swift
// NurseryConnect
// Child profile card — Clinical Sanctuary design.
// Tonal layering (no borders). Left accent stripe for alert children.

import SwiftUI

struct ChildCardView: View {
    let child: Child

    /// Deterministic avatar colour from child name hash
    private var avatarColor: Color {
        let palette: [Color] = [
            Color(hex: "2a6677"),   // primary teal
            Color(hex: "3b6850"),   // secondary green
            Color(hex: "5c5c9a"),   // muted indigo
            Color(hex: "9a5c5c"),   // muted rose
            Color(hex: "7a6a3a"),   // warm ochre
            Color(hex: "3a6a7a"),   // deep cyan
            Color(hex: "6a3a7a"),   // plum
        ]
        let index = abs(child.fullName.hashValue) % palette.count
        return palette[index]
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left accent stripe for alert children (4px — "High Priority" signal)
            if child.hasActiveAlerts {
                Rectangle()
                    .fill(Color.ncAlert)
                    .frame(width: 4)
                    .clipShape(
                        .rect(topLeadingRadius: NCRadius.card,
                              bottomLeadingRadius: NCRadius.card)
                    )
            }

            HStack(spacing: 14) {
                // Avatar
                avatarView

                // Info block
                VStack(alignment: .leading, spacing: 3) {
                    Text(child.fullName)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Color.ncOnSurface)

                    Text(child.ageDescription)
                        .font(.subheadline)
                        .foregroundStyle(Color.ncOnSurfaceVariant)

                    if child.hasActiveAlerts {
                        alertPill
                    }
                }

                Spacer()

                // Trailing — mood + chevron
                VStack(alignment: .trailing, spacing: 6) {
                    moodIndicator
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.ncOutlineVariant)
                }
            }
            .padding(.vertical, 14)
            .padding(.leading, child.hasActiveAlerts ? 12 : 14)
            .padding(.trailing, 14)
        }
        .background(Color.ncCardBg, in: RoundedRectangle(cornerRadius: NCRadius.card))
        .ncCardShadow()
    }

    // MARK: - Sub-views

    private var avatarView: some View {
        ZStack {
            Circle()
                .fill(avatarColor.opacity(0.15))
                .frame(width: 52, height: 52)
            Circle()
                .strokeBorder(avatarColor.opacity(0.25), lineWidth: 1.5)
                .frame(width: 52, height: 52)
            Text(child.firstName.prefix(1) + child.lastName.prefix(1))
                .font(.headline.weight(.bold))
                .foregroundStyle(avatarColor)
        }
    }

    private var alertPill: some View {
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

    @ViewBuilder
    private var moodIndicator: some View {
        let today = Calendar.current.startOfDay(for: Date())
        let latestObs = child.observations
            .filter { $0.timestamp >= today }
            .sorted { $0.timestamp > $1.timestamp }
            .first

        if let obs = latestObs {
            MoodIconView(mood: obs.mood, size: 34)
        }
        // No mood logged today — show nothing
    }
}
