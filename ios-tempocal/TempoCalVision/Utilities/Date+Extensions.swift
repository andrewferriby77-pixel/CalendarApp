//
//  Date+Extensions.swift
//  TempoCalVision
//

import Foundation

extension Calendar {
    static let app: Calendar = {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday
        return cal
    }()
}

extension Date {
    var startOfDay: Date { Calendar.app.startOfDay(for: self) }

    var endOfDay: Date {
        Calendar.app.date(byAdding: DateComponents(day: 1, second: -1), to: startOfDay) ?? self
    }

    var startOfWeek: Date {
        let comps = Calendar.app.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        return Calendar.app.date(from: comps) ?? self
    }

    var startOfMonth: Date {
        let comps = Calendar.app.dateComponents([.year, .month], from: self)
        return Calendar.app.date(from: comps) ?? self
    }

    func adding(days: Int) -> Date {
        Calendar.app.date(byAdding: .day, value: days, to: self) ?? self
    }

    func adding(months: Int) -> Date {
        Calendar.app.date(byAdding: .month, value: months, to: self) ?? self
    }

    func isSameDay(as other: Date) -> Bool {
        Calendar.app.isDate(self, inSameDayAs: other)
    }

    var isToday: Bool { Calendar.app.isDateInToday(self) }

    var dayNumber: Int { Calendar.app.component(.day, from: self) }

    func formatted(_ format: String) -> String {
        let f = DateFormatter()
        f.calendar = .app
        f.locale = .current
        f.dateFormat = format
        return f.string(from: self)
    }
}
