//
//  CalendarEvent.swift
//  TempoCal
//

import Foundation
import EventKit
import SwiftUI

/// A calendar event in TempoCal, backed by an EKEvent from EventKit.
struct CalendarEvent: Identifiable, Hashable {
    let id: String
    var title: String
    var start: Date
    var end: Date
    var isAllDay: Bool
    var calendarColor: CalendarColor
    var calendarTitle: String
    var location: String?
    var notes: String?

    /// The underlying EKEvent identifier for syncing back to the system calendar.
    let ekEventID: String?

    init(
        id: String = UUID().uuidString,
        title: String,
        start: Date,
        end: Date,
        isAllDay: Bool = false,
        calendarColor: CalendarColor = CalendarColor.default,
        calendarTitle: String = "Calendar",
        location: String? = nil,
        notes: String? = nil,
        ekEventID: String? = nil
    ) {
        self.id = id
        self.title = title
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.calendarColor = calendarColor
        self.calendarTitle = calendarTitle
        self.location = location
        self.notes = notes
        self.ekEventID = ekEventID
    }

    /// Convenience: build a CalendarEvent from an EKEvent.
    init(from ekEvent: EKEvent) {
        self.id = ekEvent.eventIdentifier
        self.title = ekEvent.title
        self.start = ekEvent.startDate
        self.end = ekEvent.endDate
        self.isAllDay = ekEvent.isAllDay
        self.calendarColor = CalendarColor(cgColor: ekEvent.calendar.cgColor)
        self.calendarTitle = ekEvent.calendar.title
        self.location = ekEvent.location
        self.notes = ekEvent.notes
        self.ekEventID = ekEvent.eventIdentifier
    }

    var durationLabel: String {
        if isAllDay { return "All day" }
        let minutes = Int(end.timeIntervalSince(start) / 60)
        if minutes < 60 { return "\(minutes) min" }
        let hours = Double(minutes) / 60.0
        return hours == floor(hours) ? "\(Int(hours)) hr" : String(format: "%.1f hr", hours)
    }

    var timeRangeLabel: String {
        if isAllDay { return "All day" }
        return "\(start.timeLabel) – \(end.timeLabel)"
    }

    func occurs(on day: Date) -> Bool {
        let dayStart = day.startOfDay
        let dayEnd = day.endOfDay
        return start <= dayEnd && end >= dayStart
    }
}

// MARK: - Calendar Color

/// Wraps a CGColor from a system calendar and provides a SwiftUI Color for rendering.
struct CalendarColor: Hashable, Equatable {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
    let alpha: CGFloat

    static let `default` = CalendarColor(red: 1.0, green: 0.353, blue: 0.302, alpha: 1.0)

    init(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    init(cgColor: CGColor) {
        if let comps = cgColor.components, comps.count >= 3 {
            self.red = comps[0]
            self.green = comps[1]
            self.blue = comps[2]
            self.alpha = cgColor.alpha
        } else {
            self = .default
        }
    }

    var swiftUIColor: Color {
        Color(red: red, green: green, blue: blue, opacity: alpha)
    }

    var cgColorValue: CGColor {
        CGColor(red: red, green: green, blue: blue, alpha: alpha)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(red)
        hasher.combine(green)
        hasher.combine(blue)
        hasher.combine(alpha)
    }

    static func == (lhs: CalendarColor, rhs: CalendarColor) -> Bool {
        lhs.red == rhs.red && lhs.green == rhs.green && lhs.blue == rhs.blue && lhs.alpha == rhs.alpha
    }
}
