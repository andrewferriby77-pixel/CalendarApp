//
//  CalendarEvent.swift
//  TempoCalVision
//

import Foundation
import EventKit

/// A calendar event in TempoCal Vision, backed by an EKEvent from EventKit.
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
    }

    var timeRangeLabel: String {
        if isAllDay { return "All day" }
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return "\(f.string(from: start)) – \(f.string(from: end))"
    }

    func occurs(on day: Date) -> Bool {
        let dayStart = day.startOfDay
        let dayEnd = day.endOfDay
        return start <= dayEnd && end >= dayStart
    }
}

// MARK: - Calendar Color

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
