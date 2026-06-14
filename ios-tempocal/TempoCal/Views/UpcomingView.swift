//
//  UpcomingView.swift
//  TempoCal
//

import SwiftUI
import AppIntents

/// A flowing agenda of upcoming days, grouped with sticky-feeling headers.
/// Now includes reminders mixed with events (Fantastical-style unified view).
struct UpcomingView: View {
    @Bindable var store: EventStore
    @Bindable var reminderStore: ReminderStore
    let onSelectEvent: (CalendarEvent) -> Void

    var body: some View {
        let groups = store.upcomingGrouped()
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 24) {
                if groups.isEmpty && reminderStore.reminders.isEmpty {
                    emptyState
                } else {
                    // Reminders without due dates or due today
                    let undatedReminders = reminderStore.reminders.filter { $0.dueDate == nil }
                    let todayReminders = reminderStore.reminders.filter { r in
                        guard let due = r.dueDate else { return false }
                        return Calendar.app.isDateInToday(due)
                    }

                    if !undatedReminders.isEmpty || !todayReminders.isEmpty {
                        remindersSection(undated: undatedReminders, today: todayReminders)
                    }

                    // Events grouped by day
                    ForEach(groups, id: \.day) { group in
                        section(for: group.day, events: group.events)
                    }
                }
                SiriTipView(intent: CreateEventIntent(), isVisible: .constant(true))
                    .siriTipViewStyle(.dark)
                    .padding(.top, 16)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 120)
        }
    }

    private func remindersSection(undated: [ReminderItem], today: [ReminderItem]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "checklist")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x2E9CDB))
                Text("Tasks")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                let completed = reminderStore.reminders.filter(\.isCompleted).count
                let total = reminderStore.reminders.count
                Text("\(completed)/\(total)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.inkTertiary)
            }

            ForEach(today) { reminder in
                upcomingReminderRow(reminder)
            }
            ForEach(undated) { reminder in
                upcomingReminderRow(reminder)
            }
        }
    }

    private func upcomingReminderRow(_ reminder: ReminderItem) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            reminderStore.toggle(reminder)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: reminder.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(reminder.isCompleted ? Color.green : Theme.inkTertiary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(reminder.title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(reminder.isCompleted ? Theme.inkTertiary : Theme.ink)
                        .strikethrough(reminder.isCompleted)
                    if let due = reminder.dueDate {
                        Text(reminder.dueLabel)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.inkSecondary)
                    } else {
                        Text("No due date")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.inkTertiary)
                    }
                }

                Spacer()

                if reminder.priority == .high {
                    Image(systemName: "exclamationmark.3")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.red)
                } else if reminder.priority == .medium {
                    Image(systemName: "exclamationmark.2")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.orange)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Theme.surface)
            .clipShape(.rect(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func section(for day: Date, events: [CalendarEvent]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(day.relativeDayLabel)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(day.isToday ? Theme.accent : Theme.ink)
                Spacer()
                Text(day.formatted("MMM d"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.inkTertiary)
            }
            ForEach(events) { event in
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

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(Theme.inkTertiary)
            Text("Your schedule is clear")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text("Tap + to add your first event.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.inkSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }
}
