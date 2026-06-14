//
//  ScheduleAnalyzer.swift
//  TempoCal
//

import Foundation

/// An open gap in a day's schedule.
nonisolated struct FreeSlot: Identifiable, Equatable {
    let id = UUID()
    let start: Date
    let end: Date

    var minutes: Int { Int(end.timeIntervalSince(start) / 60) }

    var durationLabel: String {
        let m = minutes
        if m < 60 { return "\(m) min" }
        let hours = Double(m) / 60.0
        return hours == floor(hours) ? "\(Int(hours)) hr free" : String(format: "%.1f hr free", hours)
    }

    var rangeLabel: String {
        "\(start.timeLabel) – \(end.timeLabel)"
    }
}

/// Pure scheduling math: conflict detection and free-slot discovery.
/// Lives off the main actor so it can be reused from widgets, watch, and previews.
nonisolated enum ScheduleAnalyzer {

    /// Default waking window used when hunting for open slots (8am–10pm).
    static let dayStartHour = 8
    static let dayEndHour = 22

    /// Returns events on `day` that overlap the proposed [start, end) range,
    /// optionally ignoring an event with `excludingID` (the one being edited).
    static func conflicts(
        start: Date,
        end: Date,
        among events: [CalendarEvent],
        on day: Date,
        excludingID: String? = nil
    ) -> [CalendarEvent] {
        events.filter { event in
            if event.id == excludingID { return false }
            if event.isAllDay { return false }
            guard event.occurs(on: day) else { return false }
            return event.start < end && event.end > start
        }
        .sorted { $0.start < $1.start }
    }

    /// Finds open gaps of at least `minMinutes` within the waking window for `day`.
    static func freeSlots(
        on day: Date,
        events: [CalendarEvent],
        minMinutes: Int = 30
    ) -> [FreeSlot] {
        let cal = Calendar.app
        let windowStart = cal.date(bySettingHour: dayStartHour, minute: 0, second: 0, of: day) ?? day.startOfDay
        let windowEnd = cal.date(bySettingHour: dayEndHour, minute: 0, second: 0, of: day) ?? day.endOfDay

        // Only consider timed events that intersect the window.
        let timed = events
            .filter { !$0.isAllDay && $0.end > windowStart && $0.start < windowEnd }
            .sorted { $0.start < $1.start }

        var slots: [FreeSlot] = []
        var cursor = windowStart

        for event in timed {
            let clampedStart = max(event.start, windowStart)
            if clampedStart > cursor {
                let gap = Int(clampedStart.timeIntervalSince(cursor) / 60)
                if gap >= minMinutes {
                    slots.append(FreeSlot(start: cursor, end: clampedStart))
                }
            }
            cursor = max(cursor, min(event.end, windowEnd))
        }

        if windowEnd > cursor {
            let gap = Int(windowEnd.timeIntervalSince(cursor) / 60)
            if gap >= minMinutes {
                slots.append(FreeSlot(start: cursor, end: windowEnd))
            }
        }

        return slots
    }

    /// Total free minutes inside the waking window for `day`.
    static func totalFreeMinutes(on day: Date, events: [CalendarEvent]) -> Int {
        freeSlots(on: day, events: events, minMinutes: 1).reduce(0) { $0 + $1.minutes }
    }

    /// Total scheduled (busy) minutes from timed events inside the waking window.
    static func busyMinutes(on day: Date, events: [CalendarEvent]) -> Int {
        let cal = Calendar.app
        let windowStart = cal.date(bySettingHour: dayStartHour, minute: 0, second: 0, of: day) ?? day.startOfDay
        let windowEnd = cal.date(bySettingHour: dayEndHour, minute: 0, second: 0, of: day) ?? day.endOfDay
        let windowMinutes = Int(windowEnd.timeIntervalSince(windowStart) / 60)
        return max(0, windowMinutes - totalFreeMinutes(on: day, events: events))
    }
}
