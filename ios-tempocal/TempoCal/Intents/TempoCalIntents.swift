import AppIntents
import EventKit

// MARK: - Create Event Intent

struct CreateEventIntent: AppIntent {
    static var title: LocalizedStringResource = "Create Event"
    static var description = IntentDescription("Creates a new calendar event in ChronoSync using natural language.")

    @Parameter(title: "Phrase", requestValueDialog: "What event would you like to create?")
    var phrase: String

    static var parameterSummary: some ParameterSummary {
        Summary("Create \(\.$phrase) in ChronoSync")
    }

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let parsed = NaturalLanguageParser.shared.parse(phrase)
        let ekStore = EKEventStore()
        let ekEvent = EKEvent(eventStore: ekStore)
        ekEvent.title = parsed.title
        ekEvent.startDate = parsed.start
        ekEvent.endDate = parsed.end
        ekEvent.isAllDay = parsed.isAllDay
        ekEvent.location = parsed.location
        ekEvent.calendar = ekStore.defaultCalendarForNewEvents

        try ekStore.save(ekEvent, span: .thisEvent)

        let dialog: IntentDialog
        if let loc = parsed.location {
            dialog = "Added \(parsed.title) at \(loc) to your calendar."
        } else {
            dialog = "Added \(parsed.title) to your calendar."
        }
        return .result(dialog: dialog)
    }
}

// MARK: - Show Schedule Intent

struct ShowScheduleIntent: AppIntent {
    static var title: LocalizedStringResource = "Show Schedule"
    static var description = IntentDescription("Shows your today's schedule from ChronoSync.")

    @Parameter(title: "Date", default: Date())
    var date: Date

    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let ekStore = EKEventStore()
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: date)
        let endOfDay = cal.date(byAdding: DateComponents(day: 1, second: -1), to: startOfDay) ?? date
        let predicate = ekStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        let events = ekStore.events(matching: predicate)

        if events.isEmpty {
            return .result(dialog: "You have nothing planned for that day.")
        }

        let count = events.count
        let titles = events.prefix(3).map { $0.title }.joined(separator: ", ")
        let dialog: IntentDialog
        if count == 1 {
            dialog = "You have one event: \(titles)."
        } else if count <= 3 {
            dialog = "You have \(count) events: \(titles)."
        } else {
            dialog = "You have \(count) events, including \(titles)."
        }
        return .result(dialog: dialog)
    }
}

// MARK: - Shortcuts Provider

struct TempoCalShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CreateEventIntent(),
            phrases: [
                "Create an event in \(.applicationName)",
                "Add event with \(.applicationName)",
                "Schedule something in \(.applicationName)",
            ],
            shortTitle: "Create Event",
            systemImageName: "calendar.badge.plus"
        )

        AppShortcut(
            intent: ShowScheduleIntent(),
            phrases: [
                "Show my schedule in \(.applicationName)",
                "What's on my calendar today with \(.applicationName)",
                "What do I have today using \(.applicationName)",
            ],
            shortTitle: "Show Schedule",
            systemImageName: "list.bullet.clipboard"
        )
    }

    static var shortcutTileColor: ShortcutTileColor = .red
}

// MARK: - Natural Language Parser

private struct NaturalLanguageParser {
    static let shared = NaturalLanguageParser()

    func parse(_ raw: String) -> ParsedResult {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        var workingTitle = text
        var detectedStart: Date?
        var detectedDuration: TimeInterval?

        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            let matches = detector.matches(in: text, options: [], range: range)
            if let match = matches.first {
                detectedStart = match.date
                if match.duration > 0 { detectedDuration = match.duration }
                if let r = Range(match.range, in: text) {
                    workingTitle.removeSubrange(r)
                }
            }
        }

        if let dur = explicitDuration(in: text) {
            detectedDuration = dur.duration
            if let r = Range(dur.range, in: workingTitle) {
                workingTitle.removeSubrange(r)
            }
        }

        let title = cleanTitle(workingTitle)
        let now = Date()
        let start = detectedStart ?? nextRoundHour(from: now)
        let isAllDay = (detectedStart != nil) && !textHasTime(text)
        let duration = detectedDuration ?? 3600
        let end = isAllDay ? start.endOfDay : start.addingTimeInterval(duration)

        return ParsedResult(title: title, start: start, end: end, isAllDay: isAllDay, location: nil)
    }
}

private struct ParsedResult {
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let location: String?
}

private func textHasTime(_ text: String) -> Bool {
    let lower = text.lowercased()
    return lower.contains(":") || lower.contains("am") || lower.contains("pm") || lower.contains("o'clock")
}

private func nextRoundHour(from date: Date) -> Date {
    let cal = Calendar.current
    var comps = cal.dateComponents([.year, .month, .day, .hour], from: date)
    comps.hour = (comps.hour ?? 0) + 1
    comps.minute = 0
    return cal.date(from: comps) ?? date
}

private func explicitDuration(in text: String) -> (duration: TimeInterval, range: NSRange)? {
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

private func cleanTitle(_ raw: String) -> String {
    var t = raw
    t = t.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    t = t.trimmingCharacters(in: .whitespacesAndNewlines)
    let connectors = ["at", "on", "in", "for", "from", "to", "the", "next", "this", "by", "with"]
    var words = t.split(separator: " ").map(String.init)
    while let last = words.last, connectors.contains(last.lowercased()) {
        words.removeLast()
    }
    t = words.joined(separator: " ")
    return t.prefix(1).uppercased() + t.dropFirst()
}
