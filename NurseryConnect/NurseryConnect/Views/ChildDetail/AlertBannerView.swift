// Views/ChildDetail/AlertBannerView.swift
// NurseryConnect
// High-visibility allergen / medical alert banner displayed at the top of
// child detail and meal logging views. Meets WCAG 2.1 AA contrast requirements.

import SwiftUI

struct AlertBannerView: View {
    let child: Child
    @State private var expanded = false

    var body: some View {
        if child.hasActiveAlerts {
            VStack(alignment: .leading, spacing: 0) {
                // Collapsed header — always visible
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        expanded.toggle()
                        HapticFeedback.warning()
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.title3.weight(.bold))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("ALLERGEN / MEDICAL ALERT")
                                .font(.caption.weight(.bold))
                                .kerning(0.5)

                            if !child.allergies.isEmpty {
                                Text(child.allergies.joined(separator: " • "))
                                    .font(.subheadline.weight(.semibold))
                            }
                        }

                        Spacer()

                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }

                // Expanded detail panel
                if expanded {
                    Divider()
                        .background(.white.opacity(0.3))
                        .padding(.horizontal, 14)

                    VStack(alignment: .leading, spacing: 8) {
                        if !child.allergies.isEmpty {
                            alertDetailRow(
                                icon: "allergens",
                                label: "Allergens",
                                value: child.allergies.joined(separator: ", ")
                            )
                        }
                        if !child.medicalNotes.isEmpty {
                            alertDetailRow(
                                icon: "cross.case.fill",
                                label: "Medical Notes",
                                value: child.medicalNotes
                            )
                        }
                        if !child.dietaryRequirements.isEmpty {
                            alertDetailRow(
                                icon: "fork.knife",
                                label: "Dietary Requirements",
                                value: child.dietaryRequirements
                            )
                        }
                        HStack(spacing: 6) {
                            Image(systemName: "phone.fill")
                                .font(.caption2)
                            Text("Emergency: \(child.emergencyContactName)  \(child.emergencyContactPhone)")
                                .font(.caption.weight(.medium))
                        }
                        .foregroundStyle(.white.opacity(0.9))
                    }
                    .padding(14)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .background(
                LinearGradient(
                    colors: [Color.ncAlert, Color.ncAlert.opacity(0.85)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: NCRadius.card)
            )
            .ncCardShadow()
        }
    }

    private func alertDetailRow(icon: String, label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 1) {
                Text(label.uppercased())
                    .font(.caption2.weight(.bold))
                    .opacity(0.8)
                Text(value)
                    .font(.subheadline)
            }
        }
        .foregroundStyle(.white)
    }
}
