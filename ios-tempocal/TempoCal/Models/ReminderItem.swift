//
//  ReminderItem.swift
//  TempoCal
//

import Foundation
import EventKit
import SwiftUI

/// A reminder/task item displayed alongside calendar events (like Fantastical's combined view).
struct ReminderItem: Identifiable, Hashable {
    let id: String
    var title: String
    var dueDate: Date?
    var isCompleted: Bool
    var priority: ReminderPriority
    var calendarTitle: String
    var calendarColor: CalendarColor
    let ekReminderID: String?

    init(
        id: String = UUID().uuidString,
        title: String,
        dueDate: Date? = nil,
        isCompleted: Bool = false,
        priority: ReminderPriority = .none,
        calendarTitle: String = "Reminders",
        calendarColor: CalendarColor = CalendarColor(red: 0.2, green: 0.6, blue: 0.86, alpha: 1.0),
        ekReminderID: String? = nil
    ) {
        self.id = id
        self.title = title
        self.dueDate = dueDate
        self.isCompleted = isCompleted
        self.priority = priority
        self.calendarTitle = calendarTitle
        self.calendarColor = calendarColor
        self.ekReminderID = ekReminderID
    }

    init(from ekReminder: EKReminder) {
        self.id = ekReminder.calendarItemIdentifier
        self.title = ekReminder.title
        self.dueDate = ekReminder.dueDateComponents?.date
        self.isCompleted = ekReminder.isCompleted
        self.priority = ReminderPriority(ekPriority: ekReminder.priority)
        self.calendarTitle = ekReminder.calendar.title
        self.calendarColor = CalendarColor(cgColor: ekReminder.calendar.cgColor)
        self.ekReminderID = ekReminder.calendarItemIdentifier
    }

    func occurs(on day: Date) -> Bool {
        guard let due = dueDate else { return false }
        return Calendar.app.isDate(due, inSameDayAs: day)
    }

    var dueLabel: String {
        guard let due = dueDate else { return "No date" }
        if Calendar.app.isDateInToday(due) { return "Today" }
        if Calendar.app.isDateInTomorrow(due) { return "Tomorrow" }
        let diff = Calendar.app.dateComponents([.day], from: Date().startOfDay, to: due.startOfDay).day ?? 0
        if diff > 0 && diff <= 7 { return due.formatted("EEEE") }
        return due.formatted("MMM d")
    }
}

enum ReminderPriority: Int, CaseIterable, Hashable {
    case none = 0
    case high = 1
    case medium = 5
    case low = 9

    init(ekPriority: Int) {
        switch ekPriority {
        case 1...4: self = .high
        case 5: self = .medium
        case 6...9: self = .low
        default: self = .none
        }
    }

    var label: String {
        switch self {
        case .none: return ""
        case .high: return "!!!"
        case .medium: return "!!"
        case .low: return "!"
        }
    }

    var color: Color {
        switch self {
        case .high: return .red
        case .medium: return .orange
        case .low: return .blue
        case .none: return .clear
        }
    }
}
