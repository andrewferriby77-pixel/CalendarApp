//
//  SearchView.swift
//  ChronoSync
//

import SwiftUI
import UIKit

/// Full-text search across calendar events and reminders, grouped by time bucket.
struct SearchView: View {
    let store: EventStore
    let reminderStore: ReminderStore
    let onSelectEvent: (CalendarEvent) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query: String = ""
    @FocusState private var focused: Bool

    private var matchingEvents: [CalendarEvent] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }
        return store.events
            .filter {
                $0.title.localizedCaseInsensitiveContains(trimmed)
                    || ($0.location?.localizedCaseInsensitiveContains(trimmed) ?? false)
                    || ($0.notes?.localizedCaseInsensitiveContains(trimmed) ?? false)
            }
    }

    private var matchingReminders: [ReminderItem] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }
        return reminderStore.reminders.filter { $0.title.localizedCaseInsensitiveContains(trimmed) }
    }

    /// Events split into Upcoming (today onward) and Past, both date-sorted.
    private var buckets: [(title: String, events: [CalendarEvent])] {
        let now = Date().startOfDay
        let upcoming = matchingEvents.filter { $0.end >= now }.sorted { $0.start < $1.start }
        let past = matchingEvents.filter { $0.end < now }.sorted { $0.start > $1.start }
        var result: [(String, [CalendarEvent])] = []
        if !upcoming.isEmpty { result.append(("Upcoming", upcoming)) }
        if !past.isEmpty { result.append(("Earlier", past)) }
        return result
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                VStack(spacing: 0) {
                    searchField
                    content
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Search")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Theme.ink)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.accent)
                }
            }
            .onAppear { focused = true }
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.inkTertiary)
            TextField("Events, locations, reminders…", text: $query)
                .font(.system(size: 16))
                .foregroundStyle(Theme.ink)
                .focused($focused)
                .submitLabel(.search)
                .autocorrectionDisabled()
            if !query.isEmpty {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.inkTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.hairline, lineWidth: 1))
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private var content: some View {
        if query.trimmingCharacters(in: .whitespaces).isEmpty {
            emptyState(icon: "magnifyingglass", title: "Search your calendar", subtitle: "Find events by title, location, or notes — and your reminders too.")
        } else if buckets.isEmpty && matchingReminders.isEmpty {
            emptyState(icon: "questionmark.circle", title: "No matches", subtitle: "Nothing found for \u{201C}\(query)\u{201D}.")
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    ForEach(buckets, id: \.title) { bucket in
                        section(title: bucket.title, count: bucket.events.count) {
                            ForEach(bucket.events) { event in
                                Button {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    onSelectEvent(event)
                                    dismiss()
                                } label: {
                                    SearchEventRow(event: event)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    if !matchingReminders.isEmpty {
                        section(title: "Reminders", count: matchingReminders.count) {
                            ForEach(matchingReminders) { reminder in
                                SearchReminderRow(reminder: reminder)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
        }
    }

    private func section<Content: View>(title: String, count: Int, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text(title.uppercased())
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.inkTertiary)
                Text("\(count)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.accent)
            }
            content()
        }
    }

    private func emptyState(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 40, weight: .regular))
                .foregroundStyle(Theme.inkTertiary)
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Theme.ink)
            Text(subtitle)
                .font(.system(size: 14))
                .foregroundStyle(Theme.inkSecondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 40)
    }
}

private struct SearchEventRow: View {
    let event: CalendarEvent

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3)
                .fill(event.calendarColor.swiftUIColor)
                .frame(width: 5)
            VStack(alignment: .leading, spacing: 3) {
                Text(event.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(event.start.formatted("EEE, MMM d"))
                    Text("·")
                    Text(event.isAllDay ? "All day" : event.start.formatted("h:mm a"))
                    if let location = event.location, !location.isEmpty {
                        Text("·")
                        Image(systemName: "mappin")
                            .font(.system(size: 10))
                        Text(location).lineLimit(1)
                    }
                }
                .font(.system(size: 13))
                .foregroundStyle(Theme.inkSecondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.inkTertiary)
        }
        .padding(14)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.hairline, lineWidth: 1))
    }
}

private struct SearchReminderRow: View {
    let reminder: ReminderItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "circle")
                .font(.system(size: 18))
                .foregroundStyle(reminder.calendarColor.swiftUIColor)
            VStack(alignment: .leading, spacing: 3) {
                Text(reminder.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Text(reminder.dueLabel)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.inkSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.hairline, lineWidth: 1))
    }
}
