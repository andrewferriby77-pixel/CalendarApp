//
//  TempoCalWidget.swift
//  TempoCalWidget
//

import WidgetKit
import SwiftUI
import EventKit

// MARK: - Timeline Entry

struct WidgetEntry: TimelineEntry {
    let date: Date
    let dayLabel: String
    let dateLabel: String
    let upcomingEvents: [WidgetEvent]
    let hasEvents: Bool
}

struct WidgetEvent: Identifiable {
    let id: String
    let title: String
    let timeLabel: String
    let colorRed: Double
    let colorGreen: Double
    let colorBlue: Double

    var color: Color {
        Color(red: colorRed, green: colorGreen, blue: colorBlue)
    }
}

// MARK: - Date Formatting Helpers

private func formatDayLabel(_ date: Date) -> String {
    let f = DateFormatter()
    f.dateFormat = "EEEE"
    return f.string(from: date)
}

private func formatDateLabel(_ date: Date) -> String {
    let f = DateFormatter()
    f.dateFormat = "MMMM d"
    return f.string(from: date)
}

private func formatTimeLabel(_ date: Date) -> String {
    let f = DateFormatter()
    f.dateFormat = "h:mm a"
    return f.string(from: date)
}

private func formatDayAndTime(_ date: Date) -> String {
    let f = DateFormatter()
    f.dateFormat = "EEE M/d"
    return f.string(from: date)
}

// MARK: - Provider

struct TodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> WidgetEntry {
        WidgetEntry(
            date: Date(),
            dayLabel: "Monday",
            dateLabel: "May 31",
            upcomingEvents: [
                WidgetEvent(id: "1", title: "Morning standup", timeLabel: "9:00 AM", colorRed: 0.2, colorGreen: 0.6, colorBlue: 0.86),
                WidgetEvent(id: "2", title: "Design review", timeLabel: "11:00 AM", colorRed: 0.2, colorGreen: 0.6, colorBlue: 0.86),
            ],
            hasEvents: true
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetEntry) -> Void) {
        let entry = makeEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetEntry>) -> Void) {
        let entry = makeEntry()
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func makeEntry() -> WidgetEntry {
        let now = Date()
        let ekStore = EKEventStore()
        let status = EKEventStore.authorizationStatus(for: .event)
        let ekEvents: [EKEvent]
        if status == .fullAccess {
            let start = now.startOfDay
            let end = now.endOfDay
            let predicate = ekStore.predicateForEvents(withStart: start, end: end, calendars: nil)
            ekEvents = ekStore.events(matching: predicate)
        } else {
            ekEvents = []
        }

        let widgetEvents: [WidgetEvent] = ekEvents
            .filter { $0.endDate >= now || $0.isAllDay }
            .prefix(4)
            .map { ek -> WidgetEvent in
                let comps = ek.calendar.cgColor.components ?? [0.2, 0.6, 0.86, 1]
                let timeStr: String
                if ek.isAllDay {
                    timeStr = "All day"
                } else if ek.startDate < now {
                    timeStr = "Now"
                } else {
                    timeStr = formatTimeLabel(ek.startDate)
                }
                return WidgetEvent(
                    id: ek.eventIdentifier,
                    title: ek.title,
                    timeLabel: timeStr,
                    colorRed: comps.count > 0 ? Double(comps[0]) : 0.2,
                    colorGreen: comps.count > 1 ? Double(comps[1]) : 0.6,
                    colorBlue: comps.count > 2 ? Double(comps[2]) : 0.86
                )
            }

        return WidgetEntry(
            date: now,
            dayLabel: formatDayLabel(now),
            dateLabel: formatDateLabel(now),
            upcomingEvents: widgetEvents,
            hasEvents: !widgetEvents.isEmpty
        )
    }
}

// MARK: - Today Widget

struct TodayWidget: Widget {
    let kind = "TodayWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayProvider()) { entry in
            TodayWidgetView(entry: entry)
        }
        .configurationDisplayName("Today")
        .description("Your schedule at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular])
    }
}

struct TodayWidgetView: View {
    var entry: WidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.dayLabel.uppercased())
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(red: 1.0, green: 0.353, blue: 0.302))
                Text(entry.dateLabel)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.primary)
            }

            if entry.hasEvents {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(entry.upcomingEvents.prefix(3)) { event in
                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(event.color)
                                .frame(width: 4, height: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.title)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                Text(event.timeLabel)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "sun.max")
                        .font(.system(size: 20))
                        .foregroundStyle(.tertiary)
                    Text("Nothing planned")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Upcoming Widget

struct UpcomingWidget: Widget {
    let kind = "UpcomingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: UpcomingProvider()) { entry in
            UpcomingWidgetView(entry: entry)
        }
        .configurationDisplayName("Upcoming")
        .description("Your next events across multiple days.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct UpcomingProvider: TimelineProvider {
    func placeholder(in context: Context) -> WidgetEntry {
        TodayProvider().placeholder(in: context)
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetEntry) -> Void) {
        let entry = makeUpcomingEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetEntry>) -> Void) {
        let entry = makeUpcomingEntry()
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func makeUpcomingEntry() -> WidgetEntry {
        let now = Date()
        let ekStore = EKEventStore()
        let status = EKEventStore.authorizationStatus(for: .event)
        let ekEvents: [EKEvent]
        if status == .fullAccess {
            let predicate = ekStore.predicateForEvents(withStart: now, end: now.adding(days: 14), calendars: nil)
            ekEvents = ekStore.events(matching: predicate)
        } else {
            ekEvents = []
        }

        let widgetEvents: [WidgetEvent] = ekEvents.prefix(8).map { ek -> WidgetEvent in
            let comps = ek.calendar.cgColor.components ?? [0.2, 0.6, 0.86, 1]
            let dayStr: String
            let cal = Calendar.current
            if cal.isDateInToday(ek.startDate) {
                dayStr = "Today"
            } else if cal.isDateInTomorrow(ek.startDate) {
                dayStr = "Tomorrow"
            } else {
                dayStr = formatDayAndTime(ek.startDate)
            }
            let timeStr = ek.isAllDay ? "All day" : formatTimeLabel(ek.startDate)
            return WidgetEvent(
                id: ek.eventIdentifier,
                title: ek.title,
                timeLabel: "\(dayStr) · \(timeStr)",
                colorRed: comps.count > 0 ? Double(comps[0]) : 0.2,
                colorGreen: comps.count > 1 ? Double(comps[1]) : 0.6,
                colorBlue: comps.count > 2 ? Double(comps[2]) : 0.86
            )
        }

        return WidgetEntry(
            date: now,
            dayLabel: "Upcoming",
            dateLabel: "",
            upcomingEvents: widgetEvents,
            hasEvents: !widgetEvents.isEmpty
        )
    }
}

struct UpcomingWidgetView: View {
    var entry: WidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Upcoming")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.primary)
                Spacer()
                if !entry.upcomingEvents.isEmpty {
                    Text("\(entry.upcomingEvents.count) events")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            if entry.hasEvents {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(entry.upcomingEvents.prefix(6)) { event in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(event.color)
                                .frame(width: 7, height: 7)
                            Text(event.title)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Spacer(minLength: 4)
                            Text(event.timeLabel)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                    }
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.system(size: 24))
                        .foregroundStyle(.tertiary)
                    Text("Your schedule is clear")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Helpers

private extension Date {
    var startOfDay: Date { Calendar.current.startOfDay(for: self) }
    var endOfDay: Date {
        var comps = DateComponents()
        comps.day = 1
        comps.second = -1
        return Calendar.current.date(byAdding: comps, to: startOfDay) ?? self
    }
    func adding(days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: self) ?? self
    }
}
