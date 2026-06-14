//
//  WatchEventParser.swift
//  TempoCalWatch
//
//  A compact natural-language parser for creating events from dictation on the wrist.
//

import Foundation

nonisolated struct WatchParsedEvent: Equatable {
    var title: String
    var start: Date
    var end: Date
    var location: String?
}

nonisolated enum WatchEventParser {
    static func parse(_ raw: String, reference: Date = Date()) -> WatchParsedEvent {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        var workingTitle = text
        var detectedStart: Date?
        var detectedDuration: TimeInterval?

        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            if let match = detector.matches(in: text, options: [], range: range).first {
                detectedStart = match.date
                if match.duration > 0 { detectedDuration = match.duration }
                if let r = Range(match.range, in: workingTitle) {
                    workingTitle.removeSubrange(r)
                }
            }
        }

        var location: String?
        if let loc = detectLocation(in: workingTitle) {
            location = loc.value
            if let r = Range(loc.range, in: workingTitle) {
                workingTitle.removeSubrange(r)
            }
        }

        var title = cleanTitle(workingTitle)
        if title.isEmpty { title = "New Event" }

        let start = detectedStart ?? nextRoundHour(from: reference)
        let end = start.addingTimeInterval(detectedDuration ?? 3600)

        return WatchParsedEvent(title: title, start: start, end: end, location: location)
    }

    private static func nextRoundHour(from date: Date) -> Date {
        var comps = Calendar.current.dateComponents([.year, .month, .day, .hour], from: date)
        comps.hour = (comps.hour ?? 0) + 1
        comps.minute = 0
        return Calendar.current.date(from: comps) ?? date
    }

    private static func detectLocation(in text: String) -> (value: String, range: NSRange)? {
        let pattern = #"\s(?:at|in)\s+([A-Za-z0-9'’&.\- ]{2,40})$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              let valueRange = Range(match.range(at: 1), in: text) else { return nil }
        let value = text[valueRange].trimmingCharacters(in: .whitespaces)
        let lower = value.lowercased()
        if lower.contains("am") || lower.contains("pm") { return nil }
        return (value, match.range)
    }

    private static func cleanTitle(_ raw: String) -> String {
        var t = raw.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        t = t.trimmingCharacters(in: .whitespacesAndNewlines)
        let connectors = ["at", "on", "in", "for", "from", "to", "the", "next", "this", "by", "with"]
        var words = t.split(separator: " ").map(String.init)
        while let last = words.last, connectors.contains(last.lowercased()) {
            words.removeLast()
        }
        t = words.joined(separator: " ")
        if t.isEmpty { return "New Event" }
        return t.prefix(1).uppercased() + t.dropFirst()
    }
}
