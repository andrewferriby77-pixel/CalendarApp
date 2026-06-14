//
//  NotificationService.swift
//  ChronoSync
//

import Foundation
import Observation
import UserNotifications

/// Schedules the personalised "Evening Digest" — a nightly local notification that previews
/// the next day's schedule (event count, first event). Settings (enabled + time) are persisted
/// in UserDefaults; digests for the next 7 evenings are scheduled with real event data.
@MainActor
@Observable
final class NotificationService {
    private let center = UNUserNotificationCenter.current()
    private let defaults = UserDefaults.standard
    private let enabledKey = "digest.enabled"
    private let minuteKey = "digest.minuteOfDay"
    private let digestPrefix = "chronosync.digest."

    private(set) var authStatus: UNAuthorizationStatus = .notDetermined

    var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: enabledKey) }
    }

    /// Minutes after midnight the digest fires (default 8:00 PM).
    var minuteOfDay: Int {
        didSet { defaults.set(minuteOfDay, forKey: minuteKey) }
    }

    init() {
        isEnabled = defaults.object(forKey: enabledKey) as? Bool ?? false
        minuteOfDay = defaults.object(forKey: minuteKey) as? Int ?? (20 * 60)
        Task { await refreshStatus() }
    }

    /// A `Date` representation of the configured digest time, for use in a DatePicker.
    var digestTime: Date {
        get {
            Calendar.app.date(bySettingHour: minuteOfDay / 60, minute: minuteOfDay % 60, second: 0, of: Date()) ?? Date()
        }
        set {
            let comps = Calendar.app.dateComponents([.hour, .minute], from: newValue)
            minuteOfDay = (comps.hour ?? 20) * 60 + (comps.minute ?? 0)
        }
    }

    func refreshStatus() async {
        let settings = await center.notificationSettings()
        authStatus = settings.authorizationStatus
    }

    /// Requests notification permission. Returns whether it was granted.
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await refreshStatus()
            return granted
        } catch {
            await refreshStatus()
            return false
        }
    }

    /// Clears and re-schedules the next 7 evening digests using current event data.
    func reschedule(events: [CalendarEvent]) async {
        await refreshStatus()
        // Always clear stale digests first.
        let pending = await center.pendingNotificationRequests()
        let staleIDs = pending.map(\.identifier).filter { $0.hasPrefix(digestPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: staleIDs)

        guard isEnabled, authStatus == .authorized || authStatus == .provisional else { return }

        let cal = Calendar.app
        let now = Date()
        let hour = minuteOfDay / 60
        let minute = minuteOfDay % 60

        for offset in 0..<7 {
            guard let fireDay = cal.date(byAdding: .day, value: offset, to: now.startOfDay),
                  let fireDate = cal.date(bySettingHour: hour, minute: minute, second: 0, of: fireDay),
                  fireDate > now else { continue }

            // The digest fired in the evening previews the FOLLOWING day.
            let previewDay = fireDay.adding(days: 1)
            let dayEvents = events
                .filter { $0.occurs(on: previewDay) }
                .sorted { lhs, rhs in
                    if lhs.isAllDay != rhs.isAllDay { return lhs.isAllDay && !rhs.isAllDay }
                    return lhs.start < rhs.start
                }

            let content = makeContent(for: dayEvents)
            let triggerComps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComps, repeats: false)
            let request = UNNotificationRequest(
                identifier: "\(digestPrefix)\(offset)",
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }

    private func makeContent(for events: [CalendarEvent]) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.sound = .default

        let timed = events.filter { !$0.isAllDay }
        let count = events.count

        if count == 0 {
            content.title = "Tomorrow is wide open"
            content.body = "No events scheduled — enjoy the free time."
        } else if count >= 4 {
            content.title = "Tomorrow looks busy"
            if let first = timed.first {
                content.body = "\(count) events. First up: \(first.title) at \(first.start.timeLabel)."
            } else {
                content.body = "\(count) events on your calendar."
            }
        } else {
            content.title = "Tomorrow's schedule"
            if let first = timed.first {
                let plural = count == 1 ? "event" : "events"
                content.body = "\(count) \(plural). First up: \(first.title) at \(first.start.timeLabel)."
            } else {
                content.body = count == 1 ? "1 all-day event." : "\(count) all-day events."
            }
        }
        return content
    }
}
