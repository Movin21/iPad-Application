// Models/MealRecord.swift
// NurseryConnect
// Meal intake record — tracks food offered/consumed and fluid intake.
// Allergen check confirmation captured for compliance.

import Foundation
import SwiftData

@Model
final class MealRecord {
    var id: UUID
    /// Auto-timestamp for audit trail
    var timestamp: Date
    var keyworkerName: String

    var mealType: MealType
    var foodOffered: String
    var foodConsumed: ConsumptionLevel
    var foodNotes: String

    // Fluid intake in millilitres
    var fluidMl: Int
    var fluidType: String   // e.g. "Water", "Milk", "Juice"

    // Allergen check — keyworker must confirm they checked before logging
    var allergenChecked: Bool
    var allergenNotes: String   // Any reaction observations

    var child: Child?

    var fluidDescription: String {
        "\(fluidMl)ml \(fluidType)"
    }

    init(
        keyworkerName: String,
        mealType: MealType = .lunch,
        foodOffered: String = "",
        foodConsumed: ConsumptionLevel = .all,
        foodNotes: String = "",
        fluidMl: Int = 0,
        fluidType: String = "Water",
        allergenChecked: Bool = false,
        allergenNotes: String = ""
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.keyworkerName = keyworkerName
        self.mealType = mealType
        self.foodOffered = foodOffered
        self.foodConsumed = foodConsumed
        self.foodNotes = foodNotes
        self.fluidMl = fluidMl
        self.fluidType = fluidType
        self.allergenChecked = allergenChecked
        self.allergenNotes = allergenNotes
    }
}
