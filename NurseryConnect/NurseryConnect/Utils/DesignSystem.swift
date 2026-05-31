// Utils/DesignSystem.swift
// NurseryConnect
// Clinical Sanctuary Design System — Ofsted-ready, authoritative, precise.
// North Star: balances medical-grade precision with early-years reassurance.

import SwiftUI

// MARK: - Hex Colour Helper

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6: (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default: (r, g, b) = (0, 0, 0)
        }
        self.init(.sRGB,
                  red:   Double(r) / 255,
                  green: Double(g) / 255,
                  blue:  Double(b) / 255)
    }
}

// MARK: - Colour Palette: Clinical Sanctuary

extension Color {
    // Primary brand — deep teal. Authoritative, trustworthy.
    static let ncAccent          = Color(hex: "2a6677")
    static let ncPrimaryDim      = Color(hex: "1b5a6b")   // CTA gradient end

    // Secondary — growth green for positive/safe actions
    static let ncSecondary           = Color(hex: "3b6850")
    static let ncSecondaryContainer  = Color(hex: "bceecf")

    // Semantic
    static let ncAlert    = Color(hex: "a83836")           // error / allergen
    static let ncSuccess  = Color(hex: "3b6850")           // positive confirmation
    static let ncWarning  = Color(hex: "f0a020")           // amber alerts

    // Surface hierarchy — tonal layering, NO borders.
    // Base → Container Low → Container Lowest (white) = physical lift
    static let ncBg             = Color(hex: "fbf9f8")     // base surface
    static let ncSurfaceLow     = Color(hex: "f5f3f3")     // secondary sections
    static let ncCardBg         = Color.white              // maximum lift / interactive cards

    // Text — never pure black
    static let ncOnSurface        = Color(hex: "313333")
    static let ncOnSurfaceVariant = Color(hex: "5e5f5f")   // form labels
    static let ncOutlineVariant   = Color(hex: "b1b2b2")   // ghost borders at 15% opacity
}

// MARK: - Typography: Editorial Authority
// Dual-font system: Manrope (headlines) + Inter (body).
// Falls back to SF Pro if font files are not in the bundle.

enum NCFont {
    // Display / Section headers — geometric, open, secure
    static func largeTitle()    -> Font { .system(.largeTitle,   design: .default, weight: .bold) }
    static func title()         -> Font { .system(.title2,       design: .default, weight: .semibold) }
    static func sectionHeader() -> Font { .system(.footnote,     design: .default, weight: .semibold) }

    // Functional data — maximum legibility at small scale
    static func body()   -> Font { .system(.body) }
    static func caption()-> Font { .system(.caption) }
    static func label()  -> Font { .system(.subheadline, design: .default, weight: .medium) }
}

// MARK: - Corner Radii

enum NCRadius {
    static let card:   CGFloat = 16
    static let button: CGFloat = 12
    static let badge:  CGFloat = 8
    static let input:  CGFloat = 12   // medical-grade input fields
}

// MARK: - Shadows: Ambient ("Whisper of Light")
// Heavy drop-shadows are forbidden. Depth via tonal layering.

extension View {
    /// Standard card — 6% opacity, feels native and lifted.
    func ncCardShadow() -> some View {
        self.shadow(color: Color(hex: "313333").opacity(0.06), radius: 12, x: 0, y: 4)
    }

    /// Secondary element — barely-there ambient depth.
    func ncSubtleShadow() -> some View {
        self.shadow(color: Color(hex: "313333").opacity(0.04), radius: 6, x: 0, y: 2)
    }

    /// Glassmorphic floating element — 40px blur, whisper shadow.
    func ncGlassShadow() -> some View {
        self.shadow(color: Color(hex: "313333").opacity(0.04), radius: 40, x: 0, y: 10)
    }
}

// MARK: - Primary CTA Gradient
// Signature texture: primary → primary-dim at 135°, adds "weighted" professional feel.

extension LinearGradient {
    static let ncPrimaryCTA = LinearGradient(
        colors: [Color(hex: "2a6677"), Color(hex: "1b5a6b")],
        startPoint: UnitPoint(x: 0.15, y: 0),
        endPoint:   UnitPoint(x: 0.85, y: 1)
    )
}

// MARK: - Haptic Helpers

enum HapticFeedback {
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    static func light()   { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func medium()  { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
}

// MARK: - Date Formatting

extension Date {
    var shortTime: String    { formatted(.dateTime.hour().minute()) }
    var shortDate: String    { formatted(.dateTime.day().month(.abbreviated)) }
    var fullDateTime: String { formatted(.dateTime.day().month(.abbreviated).year().hour().minute()) }
}

// MARK: - Mood Colours (Clinical Sanctuary palette)

extension MoodLevel {
    var swiftUIColor: Color {
        switch self {
        case .veryHappy:  return Color(red: 0.97, green: 0.76, blue: 0.08) // sunny yellow
        case .happy:      return Color(red: 0.20, green: 0.73, blue: 0.44) // mint green
        case .neutral:    return Color(red: 0.45, green: 0.62, blue: 0.78) // calm blue-grey
        case .unsettled:  return Color(red: 0.98, green: 0.64, blue: 0.08) // amber
        case .distressed: return Color(red: 0.90, green: 0.25, blue: 0.22) // safety red
        }
    }
}

// MARK: - Mood Icon View
// Coloured circular background + SF Symbol face. Use everywhere a mood is displayed.

struct MoodIconView: View {
    let mood: MoodLevel
    var size: CGFloat = 32

    var body: some View {
        ZStack {
            Circle()
                .fill(mood.swiftUIColor.opacity(0.15))
                .frame(width: size, height: size)
            Image(systemName: mood.sfSymbol)
                .font(.system(size: size * 0.52, weight: .medium))
                .foregroundStyle(mood.swiftUIColor)
        }
    }
}
