//
//  Theme.swift
//  TempoCal
//

import SwiftUI

/// Central design tokens for TempoCal. Warm editorial palette with a sunset coral accent.
enum Theme {
    // Backgrounds
    static let background = Color(hex: 0xFBF7F2)
    static let surface = Color(hex: 0xFFFFFF)
    static let surfaceElevated = Color(hex: 0xFFFCF8)

    // Ink / text
    static let ink = Color(hex: 0x1C1A17)
    static let inkSecondary = Color(hex: 0x6E6862)
    static let inkTertiary = Color(hex: 0xA8A199)

    // Accent (sunset coral)
    static let accent = Color(hex: 0xFF5A4D)
    static let accentSoft = Color(hex: 0xFFE3DE)

    static let hairline = Color(hex: 0xEAE3DA)
    static let todayHighlight = Color(hex: 0xFFEDE9)

    static let sunset = LinearGradient(
        colors: [Color(hex: 0xFF7A59), Color(hex: 0xFF5A4D), Color(hex: 0xE8456B)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

/// Palette used for calendar categories.
enum EventPalette: String, CaseIterable, Identifiable, Codable {
    case coral
    case ocean
    case forest
    case grape
    case amber
    case slate

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .coral: return Color(hex: 0xFF5A4D)
        case .ocean: return Color(hex: 0x2E9CDB)
        case .forest: return Color(hex: 0x35A98C)
        case .grape: return Color(hex: 0x8B5CF6)
        case .amber: return Color(hex: 0xF0A93B)
        case .slate: return Color(hex: 0x64748B)
        }
    }

    var name: String {
        switch self {
        case .coral: return "Personal"
        case .ocean: return "Work"
        case .forest: return "Health"
        case .grape: return "Social"
        case .amber: return "Travel"
        case .slate: return "Other"
        }
    }
}

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}
