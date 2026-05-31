// Views/MealLog/MealLogView.swift
// NurseryConnect
// Meal intake recording — food offered/consumed, fluid intake,
// and mandatory allergen check confirmation.

import SwiftUI
import SwiftData

struct MealLogView: View {
    let child: Child
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var mealType: MealType   = .lunch
    @State private var foodOffered          = ""
    @State private var foodConsumed: ConsumptionLevel = .all
    @State private var foodNotes            = ""
    @State private var fluidMl: Double      = 120
    @State private var fluidType            = "Water"
    @State private var allergenChecked      = false
    @State private var allergenNotes        = ""
    @State private var showSuccess          = false

    private let fluidTypes = ["Water", "Milk", "Formula", "Juice", "Squash", "Smoothie"]

    private var isValid: Bool {
        !foodOffered.trimmingCharacters(in: .whitespaces).isEmpty &&
        (child.hasActiveAlerts ? allergenChecked : true)
    }

    var body: some View {
        NavigationStack {
            Form {
                // Allergen reminder — mandatory check for alert children
                if child.hasActiveAlerts {
                    Section {
                        AlertBannerView(child: child)
                            .listRowInsets(.init())
                            .listRowBackground(Color.clear)
                    }
                }

                // MARK: Meal Session
                Section("Meal Session") {
                    Picker("Meal Type", selection: $mealType) {
                        ForEach(MealType.allCases, id: \.self) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                    TextField("Food offered (describe all items)", text: $foodOffered, axis: .vertical)
                        .lineLimit(2...5)
                }

                // MARK: Consumption
                Section("Food Consumption") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(child.firstName) ate:")
                            .font(.subheadline)
                            .foregroundStyle(Color.ncOnSurfaceVariant)
                        consumptionPicker
                    }
                    .padding(.vertical, 4)
                    TextField("Notes (e.g. preferred foods, refusals)…", text: $foodNotes, axis: .vertical)
                        .lineLimit(2...4)
                }

                // MARK: Fluid Intake
                Section {
                    HStack {
                        Picker("Type", selection: $fluidType) {
                            ForEach(fluidTypes, id: \.self) { t in Text(t).tag(t) }
                        }
                        Spacer()
                        Text("\(Int(fluidMl)) ml")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(Color.ncAccent)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Slider(value: $fluidMl, in: 0...500, step: 10)
                            .tint(Color.ncAccent)
                        HStack {
                            Text("0ml").font(.caption2).foregroundStyle(.secondary)
                            Spacer()
                            Text("500ml").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Fluid Intake")
                }

                // MARK: Allergen Confirmation
                if child.hasActiveAlerts {
                    Section {
                        Toggle(isOn: $allergenChecked.animation()) {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Allergen Check Confirmed")
                                        .fontWeight(.semibold)
                                    Text("I have verified this meal is safe for \(child.firstName).")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: allergenChecked ? "checkmark.shield.fill" : "shield.slash.fill")
                                    .foregroundStyle(allergenChecked ? Color.ncSuccess : Color.ncAlert)
                            }
                        }

                        if allergenChecked {
                            TextField("Any observations / reactions…", text: $allergenNotes, axis: .vertical)
                                .lineLimit(2...4)
                                .transition(.opacity)
                        }
                    } header: {
                        Text("Allergen Check")
                    } footer: {
                        if !allergenChecked && child.hasActiveAlerts {
                            Label("You must confirm allergen check before saving.", systemImage: "exclamationmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(Color.ncAlert)
                        }
                    }
                }
            }
            .navigationTitle("Record Meal")
            .navigationBarTitleDisplayMode(.inline)
            .tint(Color.ncAccent)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!isValid)
                        .fontWeight(.semibold)
                        .foregroundStyle(isValid ? Color.ncAccent : Color.ncOnSurfaceVariant)
                }
            }
            .overlay(successOverlay)
        }
    }

    // MARK: - Consumption Picker

    private var consumptionPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ConsumptionLevel.allCases, id: \.self) { level in
                    Button {
                        withAnimation(.spring(response: 0.3)) { foodConsumed = level }
                        HapticFeedback.light()
                    } label: {
                        Text(level.rawValue)
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                foodConsumed == level
                                ? Color.ncAccent
                                : Color.ncCardBg,
                                in: Capsule()
                            )
                            .foregroundStyle(foodConsumed == level ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                    .animation(.spring(response: 0.3), value: foodConsumed)
                }
            }
        }
    }

    // MARK: - Success Overlay

    @ViewBuilder
    private var successOverlay: some View {
        if showSuccess {
            VStack {
                Spacer()
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.ncSuccess)
                    Text("Meal Recorded")
                        .fontWeight(.semibold)
                }
                .padding()
                .background(.regularMaterial, in: Capsule())
                .padding(.bottom, 32)
            }
        }
    }

    // MARK: - Save

    private func save() {
        let record = MealRecord(
            keyworkerName: kKeyworkerName,
            mealType: mealType,
            foodOffered: foodOffered.trimmingCharacters(in: .whitespaces),
            foodConsumed: foodConsumed,
            foodNotes: foodNotes,
            fluidMl: Int(fluidMl),
            fluidType: fluidType,
            allergenChecked: allergenChecked,
            allergenNotes: allergenNotes
        )
        record.child = child
        child.mealRecords.append(record)
        context.insert(record)
        try? context.save()

        HapticFeedback.success()
        withAnimation { showSuccess = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { dismiss() }
    }
}
