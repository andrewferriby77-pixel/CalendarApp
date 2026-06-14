//
//  ContentView.swift
//  TempoCalWatch
//

import SwiftUI

struct ContentView: View {
    @State private var store = WatchEventStore()

    var body: some View {
        NavigationStack {
            TabView {
                TodayView(store: store)
                    .containerBackground(WatchTheme.sunset, for: .tabView)
                UpcomingWatchView(store: store)
                    .containerBackground(.black, for: .tabView)
            }
            .tabViewStyle(.verticalPage)
            .navigationDestination(for: CalendarEvent.self) { event in
                WatchEventDetailView(event: event)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    AddEventButton(store: store)
                }
            }
        }
        .task { await store.requestAccessIfNeeded() }
    }
}

// MARK: - Add via dictation

private struct AddEventButton: View {
    let store: WatchEventStore

    var body: some View {
        TextFieldLink(prompt: Text("e.g. Lunch with Maya at noon")) {
            Image(systemName: "plus")
        } onSubmit: { text in
            guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
            store.createEvent(from: text)
            WKHaptic.success()
        }
        .tint(WatchTheme.accent)
    }
}

// MARK: - Today

private struct TodayView: View {
    let store: WatchEventStore

    private var events: [CalendarEvent] { store.events(on: Date()) }
    private var nextEvent: CalendarEvent? {
        events.first { !$0.isAllDay && $0.end >= Date() } ?? events.first
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                header
                if let next = nextEvent {
                    NavigationLink(value: next) {
                        nextCard(next)
                    }
                    .buttonStyle(.plain)
                }
                ForEach(events) { event in
                    NavigationLink(value: event) {
                        WatchEventRow(event: event)
                    }
                    .buttonStyle(.plain)
                }
                if events.isEmpty {
                    Text("Nothing planned today")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.top, 20)
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Today")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(Date().fmt("EEEE").uppercased())
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white.opacity(0.85))
            Text(Date().fmt("MMMM d"))
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
            Text("\(events.count) event\(events.count == 1 ? "" : "s")")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 4)
    }

    private func nextCard(_ event: CalendarEvent) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("UP NEXT")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.7))
            Text(event.title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(2)
            Text(event.timeLabel)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.white.opacity(0.18))
        .clipShape(.rect(cornerRadius: 14))
    }
}

// MARK: - Upcoming

private struct UpcomingWatchView: View {
    let store: WatchEventStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(store.upcomingGrouped(), id: \.day) { group in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(dayLabel(group.day))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(WatchTheme.accent)
                        ForEach(group.events) { event in
                            NavigationLink(value: event) {
                                WatchEventRow(event: event)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Upcoming")
    }

    private func dayLabel(_ day: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(day) { return "Today" }
        if cal.isDateInTomorrow(day) { return "Tomorrow" }
        return day.fmt("EEEE, MMM d")
    }
}

// MARK: - Row

private struct WatchEventRow: View {
    let event: CalendarEvent

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(event.calendarColor.swiftUIColor)
                .frame(width: 4)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(event.timeLabel)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                    if let loc = event.location, !loc.isEmpty {
                        Text("· \(loc)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                            .lineLimit(1)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.12))
        .clipShape(.rect(cornerRadius: 12))
    }
}
