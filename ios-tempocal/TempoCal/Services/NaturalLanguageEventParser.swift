//
//  NaturalLanguageEventParser.swift
//  TempoCal
//

import Foundation

/// Result of parsing a natural language phrase into event or reminder components.
struct ParsedEvent: Equatable {
    var title: String
    var start: Date
    var end: Date
    var isAllDay: Bool
    var location: String?
    var palette: EventPalette
    var isReminder: Bool  // NEW: true if this is a reminder, not an event
    var recurrenceRule: RecurrencePattern?  // NEW: recurring event info
    var hasTimeComponent: Bool  // NEW: whether a specific time was detected
}

/// Detected recurrence pattern from NLP.
struct RecurrencePattern: Equatable {
    let frequency: RecurrenceFrequency
    let interval: Int
    let matchedRange: NSRange
}

enum RecurrenceFrequency: String, Equatable {
    case daily
    case weekly
    case biweekly
    case monthly
    case yearly
}

/// Turns phrases like "Lunch with Sam Friday at 1pm" or "Remind me to buy milk tomorrow"
/// into structured event/reminder data. Uses NSDataDetector for robust date/time recognition,
/// enhanced with explicit reminder detection and recurring event parsing.
enum NaturalLanguageEventParser {

    static func parse(_ raw: String, reference: Date = Date()) -> ParsedEvent {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        var workingTitle = text
        var detectedStart: Date?
        var detectedDuration: TimeInterval?
        var hadTimeComponent = false
        var isReminder = false
        var recurrence: RecurrencePattern?

        // 0. Detect reminder trigger phrases.
        isReminder = detectReminderIntent(in: text)
        if isReminder {
            // Strip reminder prefix
            for prefix in ["remind me to ", "remind me ", "todo ", "task: ", "to-do: "] {
                if workingTitle.lowercased().hasPrefix(prefix) {
                    workingTitle.removeFirst(prefix.count)
                    break
                }
            }
        }

        // 0b. Detect recurrence ("every Monday", "daily", "every other week", etc.)
        recurrence = detectRecurrence(in: text)
        if let rec = recurrence {
            if let r = Range(rec.matchedRange, in: workingTitle) {
                workingTitle.removeSubrange(r)
            }
        }

        // 1. Detect dates / times via NSDataDetector.
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            let matches = detector.matches(in: text, options: [], range: range)
            if let match = matches.first {
                detectedStart = match.date
                if match.duration > 0 { detectedDuration = match.duration }
                if let r = Range(match.range, in: text) {
                    let matched = text[r].lowercased()
                    hadTimeComponent = matched.contains(":") || matched.contains("am") || matched.contains("pm") || matched.contains("o'clock") || matched.contains("morning") || matched.contains("afternoon") || matched.contains("evening")
                    workingTitle.removeSubrange(r)
                }
            }
        }

        // 2. Detect explicit duration ("for 90 minutes", "for 2 hours").
        if detectedDuration == nil, let dur = explicitDuration(in: text) {
            detectedDuration = dur.duration
            if let r = Range(dur.range, in: workingTitle) {
                workingTitle.removeSubrange(r)
            }
        }

        // 3. Detect location ("at the office", "in Boston").
        var location: String?
        if let loc = detectLocation(in: workingTitle) {
            location = loc.value
            if let r = Range(loc.range, in: workingTitle) {
                workingTitle.removeSubrange(r)
            }
        }

        // 4. Clean leading connector words.
        var title = cleanTitle(workingTitle)
        if title.isEmpty { title = isReminder ? "New Reminder" : "New Event" }

        // 5. Resolve dates.
        let now = reference
        let start: Date
        let isAllDay = !hadTimeComponent && detectedStart != nil && !isReminder

        if let d = detectedStart {
            start = isAllDay ? d.startOfDay : d
        } else if isReminder {
            // Reminders without a date default to today
            start = now.startOfDay
        } else {
            start = nextRoundHour(from: now)
        }

        let duration = detectedDuration ?? 3600
        let end: Date
        if isAllDay {
            end = start.endOfDay
        } else {
            end = start.addingTimeInterval(duration)
        }

        let palette = inferPalette(from: text)

        return ParsedEvent(
            title: title,
            start: start,
            end: end,
            isAllDay: isAllDay,
            location: location,
            palette: palette,
            isReminder: isReminder,
            recurrenceRule: recurrence,
            hasTimeComponent: hadTimeComponent
        )
    }

    // MARK: - Reminder Detection

    private static func detectReminderIntent(in text: String) -> Bool {
        let lower = text.lowercased().trimmingCharacters(in: .whitespaces)
        let reminderPrefixes = ["remind me to", "remind me", "todo", "task:", "to-do:"]
        return reminderPrefixes.contains(where: { lower.hasPrefix($0) })
    }

    // MARK: - Recurrence Detection

    private static func detectRecurrence(in text: String) -> RecurrencePattern? {
        let lower = text.lowercased()
        let patterns: [(String, RecurrenceFrequency, Int)] = [
            ("every day", .daily, 1),
            ("daily", .daily, 1),
            ("every weekday", .daily, 1),
            ("every week", .weekly, 1),
            ("weekly", .weekly, 1),
            ("every monday", .weekly, 1),
            ("every tuesday", .weekly, 1),
            ("every wednesday", .weekly, 1),
            ("every thursday", .weekly, 1),
            ("every friday", .weekly, 1),
            ("every saturday", .weekly, 1),
            ("every sunday", .weekly, 1),
            ("every other week", .biweekly, 2),
            ("biweekly", .biweekly, 2),
            ("every month", .monthly, 1),
            ("monthly", .monthly, 1),
            ("every year", .yearly, 1),
            ("yearly", .yearly, 1),
            ("annually", .yearly, 1),
        ]

        for (phrase, freq, interval) in patterns {
            if let range = lower.range(of: phrase) {
                let nsRange = NSRange(range, in: text)
                return RecurrencePattern(frequency: freq, interval: interval, matchedRange: nsRange)
            }
        }
        return nil
    }

    // MARK: - Helpers

    private static func nextRoundHour(from date: Date) -> Date {
        var comps = Calendar.app.dateComponents([.year, .month, .day, .hour], from: date)
        comps.hour = (comps.hour ?? 0) + 1
        comps.minute = 0
        return Calendar.app.date(from: comps) ?? date
    }

    private static func explicitDuration(in text: String) -> (duration: TimeInterval, range: NSRange)? {
        let pattern = #"for\s+(\d+(?:\.\d+)?)\s*(hour|hours|hr|hrs|minute|minutes|min|mins)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              let valueRange = Range(match.range(at: 1), in: text),
              let unitRange = Range(match.range(at: 2), in: text),
              let value = Double(text[valueRange]) else { return nil }
        let unit = text[unitRange].lowercased()
        let seconds = unit.hasPrefix("h") ? value * 3600 : value * 60
        return (seconds, match.range)
    }

    private static func detectLocation(in text: String) -> (value: String, range: NSRange)? {
        let pattern = #"\s(?:at|in)\s+([A-Za-z0-9'’&.\- ]{2,40})$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              let valueRange = Range(match.range(at: 1), in: text) else { return nil }
        let value = text[valueRange].trimmingCharacters(in: .whitespaces)
        if value.lowercased().contains("am") || value.lowercased().contains("pm") { return nil }
        return (value, match.range)
    }

    private static func cleanTitle(_ raw: String) -> String {
        var t = raw
        t = t.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        t = t.trimmingCharacters(in: .whitespacesAndNewlines)
        let connectors = ["at", "on", "in", "for", "from", "to", "the", "next", "this", "by", "with", "every"]
        var words = t.split(separator: " ").map(String.init)
        while let last = words.last, connectors.contains(last.lowercased()) {
            words.removeLast()
        }
        t = words.joined(separator: " ")
        if t.isEmpty { return "New Event" }
        return t.prefix(1).uppercased() + t.dropFirst()
    }

    private static func inferPalette(from text: String) -> EventPalette {
        let lower = text.lowercased()
        let map: [(EventPalette, [String])] = [
            (.ocean, ["meeting", "work", "call", "standup", "review", "sync", "1:1", "interview", "deadline", "presentation"]),
            (.forest, ["gym", "run", "workout", "yoga", "doctor", "dentist", "health", "appointment", "therapy"]),
            (.grape, ["dinner", "lunch", "drinks", "party", "coffee", "date", "birthday", "brunch", "hangout"]),
            (.amber, ["flight", "trip", "travel", "vacation", "train", "hotel", "airport", "drive"]),
        ]
        for (palette, keywords) in map where keywords.contains(where: { lower.contains($0) }) {
            return palette
        }
        return .coral
    }
}


