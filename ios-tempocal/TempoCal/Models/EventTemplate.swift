//
//  EventTemplate.swift
//  ChronoSync
//

import Foundation

/// A one-tap quick-add template that pre-fills a new event with a name, duration,
/// accent color and optional location. Powers the Quick Add row in New Event.
nonisolated struct EventTemplate: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let icon: String
    /// Hex accent used for the chip's icon badge.
    let colorHex: UInt
    let durationMinutes: Int
    let location: String?

    init(name: String, icon: String, colorHex: UInt, durationMinutes: Int, location: String? = nil) {
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.durationMinutes = durationMinutes
        self.location = location
    }

    /// Sensible defaults covering the most common recurring blocks.
    static let defaults: [EventTemplate] = [
        EventTemplate(name: "Standup", icon: "person.3.fill", colorHex: 0x2E9CDB, durationMinutes: 15),
        EventTemplate(name: "Lunch", icon: "fork.knife", colorHex: 0xE0892B, durationMinutes: 60),
        EventTemplate(name: "Gym", icon: "figure.run", colorHex: 0x35A98C, durationMinutes: 60),
        EventTemplate(name: "Coffee", icon: "cup.and.saucer.fill", colorHex: 0x8B5E3C, durationMinutes: 30),
        EventTemplate(name: "Focus block", icon: "brain.head.profile", colorHex: 0x8B5CF6, durationMinutes: 120),
        EventTemplate(name: "Call", icon: "phone.fill", colorHex: 0xFF5A4D, durationMinutes: 30)
    ]
}
