//
//  EventStore.swift
//  TempoCal
//

import Foundation
import EventKit
import Observation
import UIKit

/// Live EventKit-backed event store. Reads/writes directly to the user's system calendars
/// (iCloud, Google, Exchange, etc.). Falls back to seeded data when EventKit access is denied
/// so the app never appears empty during onboarding.
@Observable
final class EventStore {
    private let ekStore = EKEventStore()

    private(set) var events: [CalendarEvent] = []
    private(set) var authorizationStatus: EKAuthorizationStatus = .notDetermined
    private(set) var calendars: [EKCalendar] = []
    private(set) var allCalendars: [EKCalendar] = []

    /// Whether we're using live EventKit data (true) or seed data (false).
    private(set) var isLive: Bool = false

    /// Calendar sets — groups of calendars that can be toggled on/off.
    private(set) var calendarSets: [CalendarSet] = [
        CalendarSet(name: "All Calendars", calendarIDs: [], isEnabled: true)
    ]

    /// Hidden calendar identifiers (user has toggled them off).
    private var hiddenCalendarIDs: Set<String> = []

    /// Cached seed events used when EventKit access is denied.
    private var seedEvents: [CalendarEvent] { Self.makeSeed() }

    init() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        if authorizationStatus == .fullAccess || authorizationStatus == .writeOnly {
            loadLiveData()
        } else {
            events = seedEvents
        }
    }

    // MARK: - Permissions

    /// Request calendar access. Call this from the UI when the user taps a permission prompt.
    func requestAccess() async -> Bool {
        let status: EKAuthorizationStatus
        if #available(iOS 17.0, *) {
            status = await requestFullAccess()
        } else {
            let granted = try? await ekStore.requestAccess(to: .event)
            status = (granted == true) ? .fullAccess : .denied
        }
        await MainActor.run {
            authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        }
        if status == .fullAccess {
            await MainActor.run { loadLiveData() }
            return true
        }
        return false
    }

    @available(iOS 17.0, *)
    private func requestFullAccess() async -> EKAuthorizationStatus {
        do {
            _ = try await ekStore.requestFullAccessToEvents()
            return .fullAccess
        } catch {
            return .denied
        }
    }

    // MARK: - Data Loading

    private func loadLiveData() {
        isLive = true
        allCalendars = ekStore.calendars(for: .event)
        calendars = allCalendars
        rebuildCalendarSets()
        refreshEvents()
    }

    /// Rebuild calendar sets from discovered calendars.
    private func rebuildCalendarSets() {
        var sets = calendarSets
        // Update the "All Calendars" set
        if let allIdx = sets.firstIndex(where: { $0.name == "All Calendars" }) {
            sets[allIdx] = CalendarSet(
                name: "All Calendars",
                calendarIDs: [],
                isEnabled: true
            )
        }

        // Auto-create sets based on calendar title keywords
        var addedKeywords: Set<String> = []
        for cal in allCalendars {
            let lower = cal.title.lowercased()
            let keywords: [String] = [
                lower.contains("work") || lower.contains("business") ? "Work" : nil,
                lower.contains("personal") || lower.contains("home") || lower.contains("family") ? "Personal" : nil,
                lower.contains("health") || lower.contains("fitness") || lower.contains("medical") ? "Health" : nil,
                lower.contains("travel") || lower.contains("trip") ? "Travel" : nil,
                lower.contains("social") || lower.contains("friend") ? "Social" : nil
            ].compactMap { $0 }

            for keyword in keywords where !addedKeywords.contains(keyword) {
                addedKeywords.insert(keyword)
                if !sets.contains(where: { $0.name == keyword }) {
                    sets.append(CalendarSet(name: keyword, calendarIDs: [cal.calendarIdentifier], isEnabled: true))
                }
            }
        }
        calendarSets = sets
    }

    /// Toggle a calendar set on/off.
    func toggleSet(_ setName: String) {
        guard let idx = calendarSets.firstIndex(where: { $0.name == setName }) else { return }
        var set = calendarSets[idx]
        set.isEnabled.toggle()
        calendarSets[idx] = set
        applyFilters()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// Toggle an individual calendar on/off.
    func toggleCalendar(_ calendarID: String) {
        if hiddenCalendarIDs.contains(calendarID) {
            hiddenCalendarIDs.remove(calendarID)
        } else {
            hiddenCalendarIDs.insert(calendarID)
        }
        applyFilters()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func isCalendarHidden(_ calendarID: String) -> Bool {
        hiddenCalendarIDs.contains(calendarID)
    }

    private func applyFilters() {
        // Determine which calendars to show based on sets and individual toggles
        let enabledSetIDs: Set<String> = Set(
            calendarSets
                .filter { $0.isEnabled && !$0.calendarIDs.isEmpty }
                .flatMap { $0.calendarIDs }
        )

        let allEnabled = calendarSets.first { $0.name == "All Calendars" }?.isEnabled ?? true

        if allEnabled && enabledSetIDs.isEmpty {
            calendars = allCalendars.filter { !hiddenCalendarIDs.contains($0.calendarIdentifier) }
        } else {
            calendars = allCalendars.filter { cal in
                if hiddenCalendarIDs.contains(cal.calendarIdentifier) { return false }
                if allEnabled { return true }
                return enabledSetIDs.contains(cal.calendarIdentifier)
            }
        }

        if allEnabled && hiddenCalendarIDs.isEmpty {
            calendars = allCalendars
        }
        refreshEvents()
    }

    /// Refetch events for the visible window (60 days back to 365 days ahead).
    func refreshEvents() {
        guard isLive else { return }
        let now = Date()
        let start = now.adding(days: -60)
        let end = now.adding(days: 365)
        let predicate = ekStore.predicateForEvents(withStart: start, end: end, calendars: calendars)
        let ekEvents = ekStore.events(matching: predicate)
        events = ekEvents.map { CalendarEvent(from: $0) }.sorted { $0.start < $1.start }
    }

    // MARK: - Mutations

    func add(_ event: CalendarEvent, to calendar: EKCalendar? = nil) {
        guard isLive else {
            events.append(event)
            events.sort { $0.start < $1.start }
            return
        }
        let ekEvent = EKEvent(eventStore: ekStore)
        ekEvent.title = event.title
        ekEvent.startDate = event.start
        ekEvent.endDate = event.end
        ekEvent.isAllDay = event.isAllDay
        ekEvent.location = event.location
        ekEvent.notes = event.notes
        ekEvent.calendar = calendar ?? ekStore.defaultCalendarForNewEvents ?? calendars.first

        do {
            try ekStore.save(ekEvent, span: .thisEvent)
            refreshEvents()
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } catch {
            print("[TempoCal] Failed to save event: \(error.localizedDescription)")
        }
    }

    func update(_ event: CalendarEvent) {
        guard isLive, let ekID = event.ekEventID,
              let ekEvent = ekStore.event(withIdentifier: ekID) else {
            guard let idx = events.firstIndex(where: { $0.id == event.id }) else { return }
            events[idx] = event
            events.sort { $0.start < $1.start }
            return
        }
        ekEvent.title = event.title
        ekEvent.startDate = event.start
        ekEvent.endDate = event.end
        ekEvent.isAllDay = event.isAllDay
        ekEvent.location = event.location
        ekEvent.notes = event.notes

        do {
            try ekStore.save(ekEvent, span: .thisEvent)
            refreshEvents()
        } catch {
            print("[TempoCal] Failed to update event: \(error.localizedDescription)")
        }
    }

    func delete(_ event: CalendarEvent) {
        guard isLive, let ekID = event.ekEventID,
              let ekEvent = ekStore.event(withIdentifier: ekID) else {
            events.removeAll { $0.id == event.id }
            return
        }
        do {
            try ekStore.remove(ekEvent, span: .thisEvent)
            refreshEvents()
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        } catch {
            print("[TempoCal] Failed to delete event: \(error.localizedDescription)")
        }
    }

    // MARK: - Queries

    func events(on day: Date) -> [CalendarEvent] {
        events.filter { $0.occurs(on: day) }
            .sorted { lhs, rhs in
                if lhs.isAllDay != rhs.isAllDay { return lhs.isAllDay && !rhs.isAllDay }
                return lhs.start < rhs.start
            }
    }

    func hasEvents(on day: Date) -> Bool {
        events.contains { $0.occurs(on: day) }
    }

    func palettes(on day: Date) -> [CalendarColor] {
        var seen: [CalendarColor] = []
        for event in events(on: day) where !seen.contains(event.calendarColor) {
            seen.append(event.calendarColor)
        }
        return Array(seen.prefix(3))
    }

    /// Upcoming events grouped by day, starting today.
    func upcomingGrouped(limitDays: Int = 30) -> [(day: Date, events: [CalendarEvent])] {
        let start = Date().startOfDay
        var result: [(Date, [CalendarEvent])] = []
        for offset in 0..<limitDays {
            let day = start.adding(days: offset)
            let dayEvents = events(on: day)
            if !dayEvents.isEmpty {
                result.append((day, dayEvents))
            }
        }
        return result.map { (day: $0.0, events: $0.1) }
    }

    /// Search events by title.
    func search(_ query: String) -> [CalendarEvent] {
        events.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }

    // MARK: - Connected Accounts

    /// All calendar accounts (EventKit sources) the user has connected, grouped by source
    /// and classified into a friendly provider (iCloud, Google, Exchange/Office 365, etc.).
    /// Returns empty when EventKit access has not been granted.
    func connectedAccounts() -> [CalendarAccount] {
        guard isLive else { return [] }
        let grouped = Dictionary(grouping: allCalendars, by: { $0.source.sourceIdentifier })
        return grouped.compactMap { _, cals -> CalendarAccount? in
            guard let source = cals.first?.source else { return nil }
            return CalendarAccount(
                id: source.sourceIdentifier,
                title: source.title,
                provider: CalendarProvider(source: source),
                calendars: cals.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            )
        }
        .sorted { $0.provider.sortRank != $1.provider.sortRank
            ? $0.provider.sortRank < $1.provider.sortRank
            : $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    /// Re-scan EventKit sources and calendars (call after returning from iOS Settings).
    func reloadSources() {
        guard isLive else { return }
        ekStore.refreshSourcesIfNecessary()
        allCalendars = ekStore.calendars(for: .event)
        applyFilters()
    }

    // MARK: - Seed Data (fallback when EventKit is denied)

    private static func makeSeed() -> [CalendarEvent] {
        let cal = Calendar.app
        let today = Date().startOfDay
        let defaultColor = CalendarColor.default
        func at(_ dayOffset: Int, _ hour: Int, _ minute: Int = 0) -> Date {
            let base = today.adding(days: dayOffset)
            return cal.date(bySettingHour: hour, minute: minute, second: 0, of: base) ?? base
        }

        var seed: [CalendarEvent] = []

        seed.append(CalendarEvent(title: "Morning run", start: at(0, 7), end: at(0, 8), calendarColor: .init(red: 0.208, green: 0.663, blue: 0.549, alpha: 1), calendarTitle: "Health", location: "Riverside Park"))
        seed.append(CalendarEvent(title: "Team standup", start: at(0, 9, 30), end: at(0, 10), calendarColor: .init(red: 0.180, green: 0.612, blue: 0.859, alpha: 1), calendarTitle: "Work", location: "Zoom"))
        seed.append(CalendarEvent(title: "Design review", start: at(0, 11), end: at(0, 12), calendarColor: .init(red: 0.180, green: 0.612, blue: 0.859, alpha: 1), calendarTitle: "Work", notes: "Bring the latest mockups."))
        seed.append(CalendarEvent(title: "Lunch with Maya", start: at(0, 13), end: at(0, 14), calendarColor: .init(red: 0.545, green: 0.361, blue: 0.965, alpha: 1), calendarTitle: "Social", location: "Cafe Lumen"))
        seed.append(CalendarEvent(title: "Focus block: roadmap", start: at(0, 15), end: at(0, 17), calendarColor: defaultColor))
        seed.append(CalendarEvent(title: "Dinner & a movie", start: at(0, 19, 30), end: at(0, 22), calendarColor: .init(red: 0.545, green: 0.361, blue: 0.965, alpha: 1), calendarTitle: "Social"))
        seed.append(CalendarEvent(title: "Dentist appointment", start: at(1, 9), end: at(1, 10), calendarColor: .init(red: 0.208, green: 0.663, blue: 0.549, alpha: 1), calendarTitle: "Health", location: "Bright Smile Clinic"))
        seed.append(CalendarEvent(title: "1:1 with Jordan", start: at(1, 14), end: at(1, 14, 30), calendarColor: .init(red: 0.180, green: 0.612, blue: 0.859, alpha: 1), calendarTitle: "Work"))
        seed.append(CalendarEvent(title: "Yoga class", start: at(1, 18), end: at(1, 19), calendarColor: .init(red: 0.208, green: 0.663, blue: 0.549, alpha: 1), calendarTitle: "Health", location: "Studio 9"))
        seed.append(CalendarEvent(title: "Quarterly planning", start: at(2, 10), end: at(2, 12, 30), calendarColor: .init(red: 0.180, green: 0.612, blue: 0.859, alpha: 1), calendarTitle: "Work", location: "HQ — Room 4"))
        seed.append(CalendarEvent(title: "Flight to San Francisco", start: at(4, 6, 45), end: at(4, 13), calendarColor: .init(red: 0.941, green: 0.663, blue: 0.231, alpha: 1), calendarTitle: "Travel", location: "SFO", notes: "Seat 14A · United 482"))
        seed.append(CalendarEvent(title: "Conference keynote", start: at(5, 9), end: at(5, 11), calendarColor: .init(red: 0.941, green: 0.663, blue: 0.231, alpha: 1), calendarTitle: "Travel", location: "Moscone Center"))
        seed.append(CalendarEvent(title: "Sarah's birthday", start: at(6, 0), end: at(6, 0).endOfDay, isAllDay: true, calendarColor: .init(red: 0.545, green: 0.361, blue: 0.965, alpha: 1), calendarTitle: "Social"))
        seed.append(CalendarEvent(title: "Project deadline", start: at(8, 17), end: at(8, 18), calendarColor: defaultColor, notes: "Ship v2.0"))
        seed.append(CalendarEvent(title: "Weekend hike", start: at(10, 8), end: at(10, 13), calendarColor: .init(red: 0.208, green: 0.663, blue: 0.549, alpha: 1), calendarTitle: "Health", location: "Eagle Ridge Trail"))

        return seed.sorted { $0.start < $1.start }
    }
}

// MARK: - Calendar Set Model

/// A named group of calendars that can be toggled on/off together.
struct CalendarSet: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var calendarIDs: [String]
    var isEnabled: Bool
}

// MARK: - Connected Account Models

/// A connected calendar account backed by an EventKit source.
struct CalendarAccount: Identifiable {
    let id: String
    let title: String
    let provider: CalendarProvider
    let calendars: [EKCalendar]
}

/// Friendly classification of an EventKit source into a known calendar provider.
enum CalendarProvider {
    case iCloud
    case google
    case exchange
    case onDevice
    case subscribed
    case birthdays
    case other

    init(source: EKSource) {
        let title = source.title.lowercased()
        switch source.sourceType {
        case .local:
            self = .onDevice
        case .subscribed:
            self = .subscribed
        case .birthdays:
            self = .birthdays
        case .exchange:
            self = .exchange
        case .mobileMe:
            self = .iCloud
        case .calDAV:
            if title.contains("icloud") || title.contains("me.com") || title.contains("mac.com") {
                self = .iCloud
            } else if title.contains("google") || title.contains("gmail") {
                self = .google
            } else if title.contains("exchange") || title.contains("office") || title.contains("outlook") || title.contains("microsoft") {
                self = .exchange
            } else {
                self = .other
            }
        @unknown default:
            self = .other
        }
    }

    var displayName: String {
        switch self {
        case .iCloud: return "iCloud"
        case .google: return "Google"
        case .exchange: return "Exchange / Office 365"
        case .onDevice: return "On This iPhone"
        case .subscribed: return "Subscribed"
        case .birthdays: return "Birthdays"
        case .other: return "Other"
        }
    }

    var symbol: String {
        switch self {
        case .iCloud: return "cloud.fill"
        case .google: return "g.circle.fill"
        case .exchange: return "envelope.fill"
        case .onDevice: return "iphone"
        case .subscribed: return "link"
        case .birthdays: return "gift.fill"
        case .other: return "calendar"
        }
    }

    var sortRank: Int {
        switch self {
        case .iCloud: return 0
        case .google: return 1
        case .exchange: return 2
        case .subscribed: return 3
        case .onDevice: return 4
        case .birthdays: return 5
        case .other: return 6
        }
    }
}
