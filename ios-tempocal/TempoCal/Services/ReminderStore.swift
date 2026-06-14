//
//  ReminderStore.swift
//  TempoCal
//

import Foundation
import EventKit

/// Fetches and manages Apple Reminders alongside calendar events (Fantastical-style unified view).
@Observable
final class ReminderStore {
    private let ekStore = EKEventStore()

    private(set) var reminders: [ReminderItem] = []
    private(set) var isAuthorized = false

    init() {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        if status == .fullAccess {
            isAuthorized = true
            refresh()
        }
    }

    func requestAccess() async -> Bool {
        if #available(iOS 17.0, *) {
            do {
                _ = try await ekStore.requestFullAccessToReminders()
                isAuthorized = true
                await MainActor.run { refresh() }
                return true
            } catch {
                isAuthorized = false
                return false
            }
        } else {
            let granted = try? await ekStore.requestAccess(to: .reminder)
            isAuthorized = granted == true
            if granted == true { await MainActor.run { refresh() } }
            return granted == true
        }
    }

    func refresh() {
        guard isAuthorized else { return }
        let predicate = ekStore.predicateForIncompleteReminders(
            withDueDateStarting: nil,
            ending: nil,
            calendars: nil
        )
        ekStore.fetchReminders(matching: predicate) { [weak self] ekReminders in
            guard let self, let ekReminders else { return }
            Task { @MainActor in
                self.reminders = ekReminders.map(ReminderItem.init).sorted { lhs, rhs in
                    let lhsDate = lhs.dueDate ?? Date.distantFuture
                    let rhsDate = rhs.dueDate ?? Date.distantFuture
                    return lhsDate < rhsDate
                }
            }
        }
    }

    func reminders(on day: Date) -> [ReminderItem] {
        reminders.filter { $0.occurs(on: day) }
    }

    func toggle(_ reminder: ReminderItem) {
        guard isAuthorized, let ekID = reminder.ekReminderID,
              let ekReminder = ekStore.calendarItem(withIdentifier: ekID) as? EKReminder else {
            return
        }
        ekReminder.isCompleted.toggle()
        do {
            try ekStore.save(ekReminder, commit: true)
            refresh()
        } catch {
            print("[TempoCal] Failed to toggle reminder: \(error.localizedDescription)")
        }
    }

    func add(title: String, dueDate: Date?, to calendar: EKCalendar? = nil) {
        guard isAuthorized else { return }
        let reminder = EKReminder(eventStore: ekStore)
        reminder.title = title
        if let due = dueDate {
            reminder.dueDateComponents = Calendar.app.dateComponents([.year, .month, .day], from: due)
        }
        reminder.calendar = calendar ?? ekStore.defaultCalendarForNewReminders()
        do {
            try ekStore.save(reminder, commit: true)
            refresh()
        } catch {
            print("[TempoCal] Failed to save reminder: \(error.localizedDescription)")
        }
    }
}
