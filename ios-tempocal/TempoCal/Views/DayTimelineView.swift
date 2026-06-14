//
//  DayTimelineView.swift
//  TempoCal
//

import SwiftUI
import UIKit

/// A vertical hour-by-hour timeline with positioned event blocks for a single day.
/// Now also shows reminders due on this day.
struct DayTimelineView: View {
    let day: Date
    let events: [CalendarEvent]
    let reminders: [ReminderItem]
    let onSelect: (CalendarEvent) -> Void

    private let hourHeight: CGFloat = 64
    private let startHour: Int = 0
    private let endHour: Int = 24
    private let gutter: CGFloat = 56

    private var timedEvents: [CalendarEvent] { events.filter { !$0.isAllDay } }
    private var allDayEvents: [CalendarEvent] { events.filter { $0.isAllDay } }
    private var todayReminders: [ReminderItem] { reminders }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                if !allDayEvents.isEmpty {
                    allDayStrip
                        .padding(.horizontal, 16)
                        .padding(.bottom, 4)
                }

                if !todayReminders.isEmpty {
                    remindersStrip
                        .padding(.horizontal, 16)
                        .padding(.bottom, 4)
                }

                ZStack(alignment: .topLeading) {
                    hourGrid
                    if day.isToday { nowIndicator }
                    eventBlocks
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 120)
            }
            .onAppear {
                let target = day.isToday ? Calendar.app.component(.hour, from: Date()) : 8
                withAnimation { proxy.scrollTo(max(0, target - 1), anchor: .top) }
            }
        }
    }

    private var allDayStrip: some View {
        VStack(spacing: 8) {
            ForEach(allDayEvents) { event in
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onSelect(event)
                } label: {
                    HStack(spacing: 10) {
                        Circle().fill(event.calendarColor.swiftUIColor).frame(width: 8, height: 8)
                        Text(event.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                        Spacer()
                        Text("All day")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.inkSecondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(event.calendarColor.swiftUIColor.opacity(0.12))
                    .clipShape(.rect(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var remindersStrip: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "checklist")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.inkTertiary)
                Text("REMINDERS")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.inkTertiary)
                Spacer()
                Text("\(todayReminders.filter { $0.isCompleted }.count)/\(todayReminders.count)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.inkTertiary)
            }
            .padding(.horizontal, 2)

            ForEach(todayReminders) { reminder in
                ReminderRow(reminder: reminder)
            }
        }
    }

    private var hourGrid: some View {
        VStack(spacing: 0) {
            ForEach(startHour..<endHour, id: \.self) { hour in
                HStack(alignment: .top, spacing: 8) {
                    Text(hourLabel(hour))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.inkTertiary)
                        .frame(width: gutter - 12, alignment: .trailing)
                        .offset(y: -7)
                    Rectangle()
                        .fill(Theme.hairline)
                        .frame(height: 1)
                }
                .frame(height: hourHeight, alignment: .top)
                .id(hour)
            }
        }
    }

    private var eventBlocks: some View {
        ForEach(layout(timedEvents)) { placed in
            let event = placed.event
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onSelect(event)
            } label: {
                eventBlockContent(event, compact: placed.height < 44)
            }
            .buttonStyle(.plain)
            .frame(width: placed.width, height: max(placed.height - 4, 26), alignment: .topLeading)
            .offset(x: gutter + placed.xOffset, y: placed.yOffset)
        }
    }

    private func eventBlockContent(_ event: CalendarEvent, compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(event.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .lineLimit(compact ? 1 : 2)
            if !compact {
                Text(event.timeRangeLabel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.inkSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, compact ? 4 : 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            ZStack(alignment: .leading) {
                event.calendarColor.swiftUIColor.opacity(0.14)
                Rectangle().fill(event.calendarColor.swiftUIColor).frame(width: 4)
            }
        )
        .clipShape(.rect(cornerRadius: 10))
    }

    private var nowIndicator: some View {
        let minutes = CGFloat(Calendar.app.component(.hour, from: Date()) * 60 + Calendar.app.component(.minute, from: Date()))
        let y = minutes / 60 * hourHeight
        return HStack(spacing: 0) {
            Circle().fill(Theme.accent).frame(width: 9, height: 9)
            Rectangle().fill(Theme.accent).frame(height: 2)
        }
        .offset(x: gutter - 4, y: y)
    }

    // MARK: - Layout engine

    private struct PlacedEvent: Identifiable {
        let id: String
        let event: CalendarEvent
        let yOffset: CGFloat
        let height: CGFloat
        let xOffset: CGFloat
        let width: CGFloat
    }

    private func yPosition(for date: Date) -> CGFloat {
        let comps = Calendar.app.dateComponents([.hour, .minute], from: date)
        let minutes = CGFloat((comps.hour ?? 0) * 60 + (comps.minute ?? 0))
        return minutes / 60 * hourHeight
    }

    /// Groups overlapping events into columns so they sit side-by-side.
    private func layout(_ events: [CalendarEvent]) -> [PlacedEvent] {
        let sorted = events.sorted { $0.start < $1.start }
        var clusters: [[CalendarEvent]] = []
        for event in sorted {
            if var last = clusters.last,
               last.contains(where: { $0.end > event.start }) {
                last.append(event)
                clusters[clusters.count - 1] = last
            } else {
                clusters.append([event])
            }
        }

        let totalWidth: CGFloat = UIScreen.main.bounds.width - 32 - gutter
        var placed: [PlacedEvent] = []
        for cluster in clusters {
            let columns = cluster.count
            let colWidth = totalWidth / CGFloat(columns)
            for (index, event) in cluster.enumerated() {
                let startY = yPosition(for: max(event.start, day.startOfDay))
                let endY = yPosition(for: min(event.end, day.endOfDay))
                placed.append(PlacedEvent(
                    id: event.id,
                    event: event,
                    yOffset: startY,
                    height: max(endY - startY, 26),
                    xOffset: colWidth * CGFloat(index),
                    width: colWidth - 4
                ))
            }
        }
        return placed
    }

    private func hourLabel(_ hour: Int) -> String {
        if hour == 0 { return "12 AM" }
        if hour == 12 { return "Noon" }
        if hour < 12 { return "\(hour) AM" }
        return "\(hour - 12) PM"
    }
}

// MARK: - Reminder Row

private struct ReminderRow: View {
    let reminder: ReminderItem

    var body: some View {
        HStack(spacing: 10) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                // Toggle handled by parent
            } label: {
                Image(systemName: reminder.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(reminder.isCompleted ? Color.green : Theme.inkTertiary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(reminder.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(reminder.isCompleted ? Theme.inkTertiary : Theme.ink)
                    .strikethrough(reminder.isCompleted)
                if let due = reminder.dueDate, !Calendar.app.isDateInToday(due) {
                    Text(reminder.dueLabel)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.inkTertiary)
                }
            }

            Spacer()

            if reminder.priority == .high {
                Text("!!!")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 6)
    }
}
