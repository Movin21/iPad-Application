// Models/Child.swift
// NurseryConnect
// SwiftData model representing a child in the nursery.
// GDPR: Keyworker only sees children assigned to them.

import Foundation
import SwiftData

// MARK: - Supporting Enums

/// EYFS 2024 curriculum areas of learning
enum EYFSArea: String, Codable, CaseIterable {
    case communication        = "Communication & Language"
    case physical             = "Physical Development"
    case personalSocial       = "Personal, Social & Emotional"
    case literacy             = "Literacy"
    case mathematics          = "Mathematics"
    case understanding        = "Understanding the World"
    case expressive           = "Expressive Arts & Design"

    var sfSymbol: String {
        switch self {
        case .communication:  return "bubble.left.and.bubble.right"
        case .physical:       return "figure.run"
        case .personalSocial: return "heart.circle"
        case .literacy:       return "book"
        case .mathematics:    return "number.circle"
        case .understanding:  return "globe"
        case .expressive:     return "paintpalette"
        }
    }
}

/// Child's general mood/wellbeing level
enum MoodLevel: String, Codable, CaseIterable {
    case veryHappy  = "Very Happy"
    case happy      = "Happy"
    case neutral    = "Settled"
    case unsettled  = "Unsettled"
    case distressed = "Distressed"

    var emoji: String {
        switch self {
        case .veryHappy:  return "😄"
        case .happy:      return "🙂"
        case .neutral:    return "😐"
        case .unsettled:  return "😟"
        case .distressed: return "😢"
        }
    }

    var color: String {
        switch self {
        case .veryHappy:  return "green"
        case .happy:      return "mint"
        case .neutral:    return "yellow"
        case .unsettled:  return "orange"
        case .distressed: return "red"
        }
    }

    var sfSymbol: String {
        switch self {
        case .veryHappy:  return "face.smiling.inverse"
        case .happy:      return "face.smiling"
        case .neutral:    return "face.dashed"
        case .unsettled:  return "exclamationmark.circle"
        case .distressed: return "xmark.circle.fill"
        }
    }
}

/// Type of nappy change event
enum NappyType: String, Codable, CaseIterable {
    case wet    = "Wet"
    case soiled = "Soiled"
    case dry    = "Dry / Check"
    case mixed  = "Wet & Soiled"
}

/// Food consumption level
enum ConsumptionLevel: String, Codable, CaseIterable {
    case all      = "All"
    case most     = "Most"
    case half     = "Half"
    case little   = "A Little"
    case refused  = "Refused"
}

/// Meal type session
enum MealType: String, Codable, CaseIterable {
    case breakfast = "Breakfast"
    case midMorningSnack = "Mid-Morning Snack"
    case lunch     = "Lunch"
    case afternoonSnack = "Afternoon Snack"
    case tea       = "Tea"
}

/// EYFS milestone achievement status
enum MilestoneStatus: String, Codable, CaseIterable {
    case notStarted = "Not Yet"
    case emerging   = "Emerging"
    case developing = "Developing"
    case achieved   = "Achieved"

    var color: String {
        switch self {
        case .notStarted: return "gray"
        case .emerging:   return "orange"
        case .developing: return "blue"
        case .achieved:   return "green"
        }
    }
}

/// RIDDOR-aligned incident categories
enum IncidentType: String, Codable, CaseIterable {
    case accident      = "Accident"
    case nearMiss      = "Near Miss"
    case illness       = "Illness / Medical"
    case behavioural   = "Behavioural"
    case safeguarding  = "Safeguarding Concern"

    var isRiddorRelevant: Bool {
        switch self {
        case .accident, .nearMiss: return true
        default: return false
        }
    }
}

/// Incident review/countersignature workflow state
enum ReviewStatus: String, Codable, CaseIterable {
    case pendingReview     = "Pending Review"
    case underReview       = "Under Review"
    case countersigned     = "Countersigned"
    case requiresAction    = "Requires Action"

    var sfSymbol: String {
        switch self {
        case .pendingReview:  return "clock.badge.exclamationmark"
        case .underReview:    return "eye.circle"
        case .countersigned:  return "checkmark.seal"
        case .requiresAction: return "exclamationmark.triangle"
        }
    }

    var color: String {
        switch self {
        case .pendingReview:  return "orange"
        case .underReview:    return "blue"
        case .countersigned:  return "green"
        case .requiresAction: return "red"
        }
    }
}

// MARK: - Child Model

@Model
final class Child {
    // Identity
    var id: UUID
    var firstName: String
    var lastName: String
    var dateOfBirth: Date
    var photoData: Data?

    // GDPR: Keyworker name used to filter — each KW only sees their children
    var assignedKeyworkerName: String

    // Medical / allergen info — surfaces as high-visibility alerts
    var allergies: [String]
    var medicalNotes: String
    var dietaryRequirements: String

    // Emergency contact (minimal for MVP)
    var emergencyContactName: String
    var emergencyContactPhone: String

    // Relationship back-links (SwiftData handles the inverse)
    @Relationship(deleteRule: .cascade) var observations: [DailyLog]
    @Relationship(deleteRule: .cascade) var mealRecords: [MealRecord]
    @Relationship(deleteRule: .cascade) var incidents: [Incident]
    @Relationship(deleteRule: .cascade) var milestones: [EYFSMilestone]

    // Computed helpers
    var fullName: String { "\(firstName) \(lastName)" }

    var ageDescription: String {
        let cal = Calendar.current
        let components = cal.dateComponents([.year, .month, .day], from: dateOfBirth, to: Date())
        let years  = components.year  ?? 0
        let months = components.month ?? 0
        let days   = components.day   ?? 0
        if years > 0 {
            return "\(years)y \(months)m \(days)d"
        } else if months > 0 {
            return "\(months)m \(days)d"
        }
        return "\(days) days"
    }

    /// True on the child's birthday (month + day match today regardless of year)
    var isBirthdayToday: Bool {
        let cal = Calendar.current
        let today = Date()
        return cal.component(.month, from: dateOfBirth) == cal.component(.month, from: today) &&
               cal.component(.day,   from: dateOfBirth) == cal.component(.day,   from: today)
    }

    /// Formatted date of birth, e.g. "12 March 2022"
    var birthdayFormatted: String {
        dateOfBirth.formatted(.dateTime.day().month(.wide).year())
    }

    var hasActiveAlerts: Bool {
        !allergies.isEmpty || !medicalNotes.isEmpty
    }

    init(
        firstName: String,
        lastName: String,
        dateOfBirth: Date,
        assignedKeyworkerName: String,
        allergies: [String] = [],
        medicalNotes: String = "",
        dietaryRequirements: String = "",
        emergencyContactName: String = "",
        emergencyContactPhone: String = ""
    ) {
        self.id = UUID()
        self.firstName = firstName
        self.lastName = lastName
        self.dateOfBirth = dateOfBirth
        self.assignedKeyworkerName = assignedKeyworkerName
        self.allergies = allergies
        self.medicalNotes = medicalNotes
        self.dietaryRequirements = dietaryRequirements
        self.emergencyContactName = emergencyContactName
        self.emergencyContactPhone = emergencyContactPhone
        self.observations = []
        self.mealRecords = []
        self.incidents = []
        self.milestones = []
    }
}
