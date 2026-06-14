//
//  WatchModels.swift
//  TempoCalWatch
//

import SwiftUI
import EventKit
import Observation
import WatchConnectivity
import WidgetKit

// MARK: - Theme

enum WatchTheme {
    static let accent = Color(red: 1.0, green: 0.353, blue: 0.302)
    static let sunset = LinearGradient(
        colors: [Color(red: 1.0, green: 0.478, blue: 0.349), Color(red: 1.0, green: 0.353, blue: 0.302), Color(red: 0.909, green: 0.271, blue: 0.42)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
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

// MARK: - Event

struct CalendarEvent: Identifiable, Hashable {
    let id: String
    var title: String
    var start: Date
    var end: Date
    var isAllDay: Bool
    var calendarColor: CalendarColor
    var calendarTitle: String
    var location: String?

    init(
        id: String = UUID().uuidString,
        title: String,
        start: Date,
        end: Date,
        isAllDay: Bool = false,
        calendarColor: CalendarColor = CalendarColor.default,
        calendarTitle: String = "Calendar",
        location: String? = nil
    ) {
        self.id = id
        self.title = title
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.calendarColor = calendarColor
        self.calendarTitle = calendarTitle
        self.location = location
    }

    var timeLabel: String {
        if isAllDay { return "All day" }
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: start)
    }

    func occurs(on day: Date) -> Bool {
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: day)
        let dayEnd = cal.date(byAdding: DateComponents(day: 1, second: -1), to: dayStart) ?? day
        return start <= dayEnd && end >= dayStart
    }
}

extension Date {
    var startOfDayW: Date { Calendar.current.startOfDay(for: self) }
    var endOfDayW: Date {
        Calendar.current.date(byAdding: DateComponents(day: 1, second: -1), to: startOfDayW) ?? self
    }
    func addingDaysW(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: self) ?? self
    }
    func fmt(_ format: String) -> String {
        let f = DateFormatter()
        f.dateFormat = format
        return f.string(from: self)
    }
}

// MARK: - Store (EventKit-backed)

@Observable
final class WatchEventStore {
    private let ekStore = EKEventStore()
    private(set) var events: [CalendarEvent] = []
    private(set) var isLive: Bool = false
    /// Premium entitlement mirrored from the paired iPhone via WatchConnectivity.
    var isPremium: Bool = SharedComplicationStore.load().premiumActive
    private let connectivity = WatchConnectivityReceiver()

    init() {
        loadIfAuthorized()
        connectivity.onPremiumChange = { [weak self] active in
            guard let self else { return }
            self.isPremium = active
            self.publishSnapshot()
        }
        connectivity.activate()
    }

    private func loadIfAuthorized() {
        let status = EKEventStore.authorizationStatus(for: .event)
        if status == .fullAccess || status == .writeOnly {
            isLive = true
            refresh()
        } else {
            events = Self.seed()
            publishSnapshot()
        }
    }

    /// Requests calendar access then refreshes. Used before creating an event from the wrist.
    func requestAccessIfNeeded() async {
        let status = EKEventStore.authorizationStatus(for: .event)
        guard status == .notDetermined else {
            isLive = (status == .fullAccess || status == .writeOnly)
            if isLive { refresh() }
            return
        }
        do {
            let granted = try await ekStore.requestFullAccessToEvents()
            isLive = granted
            if granted { refresh() }
        } catch {
            isLive = false
        }
    }

    /// Creates a calendar event from a dictated phrase. watchOS EventKit is read-only, so the
    /// phrase is handed to the paired iPhone (which writes to the real calendar) while we add an
    /// optimistic copy locally for instant feedback.
    @discardableResult
    func createEvent(from phrase: String) -> CalendarEvent {
        let parsed = WatchEventParser.parse(phrase)
        connectivity.sendCreateRequest(phrase)
        let local = CalendarEvent(title: parsed.title, start: parsed.start, end: parsed.end, location: parsed.location)
        events.append(local)
        publishSnapshot()
        return local
    }

    func refresh() {
        guard isLive else { return }
        let now = Date()
        let start = now.addingDaysW(-14)
        let end = now.addingDaysW(14)
        let predicate = ekStore.predicateForEvents(withStart: start, end: end, calendars: nil)
        events = ekStore.events(matching: predicate).map { ekEvent in
            CalendarEvent(
                id: ekEvent.eventIdentifier,
                title: ekEvent.title,
                start: ekEvent.startDate,
                end: ekEvent.endDate,
                isAllDay: ekEvent.isAllDay,
                calendarColor: CalendarColor(cgColor: ekEvent.calendar.cgColor),
                calendarTitle: ekEvent.calendar.title,
                location: ekEvent.location
            )
        }
        publishSnapshot()
    }

    /// Writes the current schedule + premium state to the shared App Group and reloads complications.
    func publishSnapshot() {
        let today = events(on: Date())
        let next = today.first { !$0.isAllDay && $0.end >= Date() } ?? today.first
        let tomorrow = events(on: Date().addingDaysW(1))
        let tomorrowFirst = tomorrow.first { !$0.isAllDay } ?? tomorrow.first
        let snapshot = ComplicationSnapshot(
            premiumActive: isPremium,
            nextTitle: next?.title,
            nextStart: next?.start,
            nextColor: next.map { [$0.calendarColor.red, $0.calendarColor.green, $0.calendarColor.blue].map(Double.init) } ?? [1.0, 0.353, 0.302],
            todayCount: today.count,
            tomorrowTitle: tomorrowFirst?.title,
            tomorrowStart: tomorrowFirst?.start,
            tomorrowColor: tomorrowFirst.map { [$0.calendarColor.red, $0.calendarColor.green, $0.calendarColor.blue].map(Double.init) } ?? [1.0, 0.353, 0.302],
            tomorrowCount: tomorrow.count,
            generatedAt: Date()
        )
        SharedComplicationStore.save(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }

    func events(on day: Date) -> [CalendarEvent] {
        events.filter { $0.occurs(on: day) }
            .sorted { lhs, rhs in
                if lhs.isAllDay != rhs.isAllDay { return lhs.isAllDay }
                return lhs.start < rhs.start
            }
    }

    func upcomingGrouped(limitDays: Int = 7) -> [(day: Date, events: [CalendarEvent])] {
        let start = Date().startOfDayW
        var result: [(Date, [CalendarEvent])] = []
        for offset in 0..<limitDays {
            let day = start.addingDaysW(offset)
            let e = events(on: day)
            if !e.isEmpty { result.append((day, e)) }
        }
        return result.map { (day: $0.0, events: $0.1) }
    }

    private static func seed() -> [CalendarEvent] {
        let cal = Calendar.current
        let today = Date().startOfDayW
        func at(_ d: Int, _ h: Int, _ m: Int = 0) -> Date {
            let base = today.addingDaysW(d)
            return cal.date(bySettingHour: h, minute: m, second: 0, of: base) ?? base
        }
        return [
            CalendarEvent(title: "Morning run", start: at(0, 7), end: at(0, 8), calendarColor: .init(red: 0.208, green: 0.663, blue: 0.549, alpha: 1), calendarTitle: "Health", location: "Riverside Park"),
            CalendarEvent(title: "Team standup", start: at(0, 9, 30), end: at(0, 10), calendarColor: .init(red: 0.180, green: 0.612, blue: 0.859, alpha: 1), calendarTitle: "Work", location: "Zoom"),
            CalendarEvent(title: "Design review", start: at(0, 11), end: at(0, 12), calendarColor: .init(red: 0.180, green: 0.612, blue: 0.859, alpha: 1), calendarTitle: "Work"),
            CalendarEvent(title: "Lunch with Maya", start: at(0, 13), end: at(0, 14), calendarColor: .init(red: 0.545, green: 0.361, blue: 0.965, alpha: 1), calendarTitle: "Social", location: "Cafe Lumen"),
            CalendarEvent(title: "Focus: roadmap", start: at(0, 15), end: at(0, 17), calendarColor: .default),
            CalendarEvent(title: "Dinner & a movie", start: at(0, 19, 30), end: at(0, 22), calendarColor: .init(red: 0.545, green: 0.361, blue: 0.965, alpha: 1), calendarTitle: "Social"),
            CalendarEvent(title: "Dentist", start: at(1, 9), end: at(1, 10), calendarColor: .init(red: 0.208, green: 0.663, blue: 0.549, alpha: 1), calendarTitle: "Health"),
            CalendarEvent(title: "1:1 with Jordan", start: at(1, 14), end: at(1, 14, 30), calendarColor: .init(red: 0.180, green: 0.612, blue: 0.859, alpha: 1), calendarTitle: "Work"),
            CalendarEvent(title: "Yoga class", start: at(1, 18), end: at(1, 19), calendarColor: .init(red: 0.208, green: 0.663, blue: 0.549, alpha: 1), calendarTitle: "Health"),
            CalendarEvent(title: "Quarterly planning", start: at(2, 10), end: at(2, 12, 30), calendarColor: .init(red: 0.180, green: 0.612, blue: 0.859, alpha: 1), calendarTitle: "Work"),
        ]
    }
}
