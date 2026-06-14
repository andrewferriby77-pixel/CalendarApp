//
//  MonthView.swift
//  TempoCal
//

import SwiftUI

/// A scrollable month grid with event dots, and the selected day's agenda below.
struct MonthView: View {
    @Bindable var store: EventStore
    @Bindable var reminderStore: ReminderStore
    @Binding var selectedDate: Date
    @Binding var visibleMonth: Date
    let onSelectEvent: (CalendarEvent) -> Void

    private let weekdaySymbols = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        VStack(spacing: 0) {
            weekdayHeader
            monthGrid
                .padding(.horizontal, 16)
            Divider().background(Theme.hairline).padding(.top, 8)
            agenda
        }
    }

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.inkTertiary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private var monthGrid: some View {
        let days = daysInGrid(for: visibleMonth)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
        return LazyVGrid(columns: columns, spacing: 4) {
            ForEach(days, id: \.self) { day in
                dayCell(day)
            }
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let inMonth = Calendar.app.isDate(day, equalTo: visibleMonth, toGranularity: .month)
        let isSelected = day.isSameDay(as: selectedDate)
        let palettes = store.palettes(on: day)

        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedDate = day
            }
        } label: {
            VStack(spacing: 5) {
                Text("\(day.dayNumber)")
                    .font(.system(size: 15, weight: day.isToday ? .bold : .medium))
                    .foregroundStyle(dayTextColor(day, inMonth: inMonth, isSelected: isSelected))
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(isSelected ? AnyShapeStyle(Theme.sunset) : AnyShapeStyle(Color.clear))
                    )
                    .overlay(
                        Circle()
                            .stroke(day.isToday && !isSelected ? Theme.accent : Color.clear, lineWidth: 1.5)
                    )

                HStack(spacing: 3) {
                    ForEach(Array(palettes.enumerated()), id: \.offset) { _, color in
                        Circle()
                            .fill(color.swiftUIColor)
                            .frame(width: 5, height: 5)
                    }
                }
                .frame(height: 8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(inMonth ? 1 : 0.35)
    }

    private func dayTextColor(_ day: Date, inMonth: Bool, isSelected: Bool) -> Color {
        if isSelected { return .white }
        if day.isToday { return Theme.accent }
        return Theme.ink
    }

    private var agenda: some View {
        let dayEvents = store.events(on: selectedDate)
        let dayReminders = reminderStore.reminders(on: selectedDate)
        return ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 10) {
                Text(selectedDate.relativeDayLabel)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .padding(.top, 12)

                if dayEvents.isEmpty && dayReminders.isEmpty {
                    emptyState
                } else {
                    // Reminders first
                    ForEach(dayReminders) { reminder in
                        HStack(spacing: 10) {
                            Image(systemName: reminder.isCompleted ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 18))
                                .foregroundStyle(reminder.isCompleted ? Color.green : Theme.inkTertiary)
                            Text(reminder.title)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(reminder.isCompleted ? Theme.inkTertiary : Theme.ink)
                                .strikethrough(reminder.isCompleted)
                            Spacer()
                            if reminder.priority == .high {
                                Text("!!!")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.red)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    // Divider if both reminders and events present
                    if !dayReminders.isEmpty && !dayEvents.isEmpty {
                        Divider().background(Theme.hairline).padding(.vertical, 4)
                    }

                    // Events
                    ForEach(dayEvents) { event in
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            onSelectEvent(event)
                        } label: {
                            EventRow(event: event)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 120)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "sun.max")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(Theme.inkTertiary)
            Text("Nothing planned")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.inkSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func daysInGrid(for month: Date) -> [Date] {
        let firstOfMonth = month.startOfMonth
        let gridStart = firstOfMonth.startOfWeek
        return (0..<42).map { gridStart.adding(days: $0) }
    }
}
