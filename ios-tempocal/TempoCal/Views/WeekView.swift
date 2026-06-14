//
//  WeekView.swift
//  TempoCal
//

import SwiftUI

/// A week strip selector sitting above the day timeline.
struct WeekView: View {
    @Bindable var store: EventStore
    @Bindable var reminderStore: ReminderStore
    @Binding var selectedDate: Date
    let onSelectEvent: (CalendarEvent) -> Void

    private var weekDays: [Date] {
        let start = selectedDate.startOfWeek
        return (0..<7).map { start.adding(days: $0) }
    }

    var body: some View {
        VStack(spacing: 0) {
            weekStrip
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            Divider().background(Theme.hairline)
            DayTimelineView(
                day: selectedDate,
                events: store.events(on: selectedDate),
                reminders: reminderStore.reminders(on: selectedDate),
                onSelect: onSelectEvent
            )
        }
    }

    private var weekStrip: some View {
        HStack(spacing: 4) {
            ForEach(weekDays, id: \.self) { day in
                dayPill(day)
            }
        }
    }

    private func dayPill(_ day: Date) -> some View {
        let isSelected = day.isSameDay(as: selectedDate)
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                selectedDate = day
            }
        } label: {
            VStack(spacing: 6) {
                Text(day.formatted("EEE").uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isSelected ? .white.opacity(0.85) : Theme.inkTertiary)
                Text("\(day.dayNumber)")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(isSelected ? .white : (day.isToday ? Theme.accent : Theme.ink))
                Circle()
                    .fill(store.hasEvents(on: day) ? (isSelected ? Color.white : Theme.accent) : Color.clear)
                    .frame(width: 5, height: 5)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? AnyShapeStyle(Theme.sunset) : AnyShapeStyle(Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(day.isToday && !isSelected ? Theme.accentSoft : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}
