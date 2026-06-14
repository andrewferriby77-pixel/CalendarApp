//
//  WatchEventDetailView.swift
//  TempoCalWatch
//

import SwiftUI

/// Tap-through detail for an event row, with handoff actions for the paired iPhone.
struct WatchEventDetailView: View {
    let event: CalendarEvent

    private var dateRangeLabel: String {
        if event.isAllDay { return "All day · \(event.start.fmt("EEE, MMM d"))" }
        let f = DateFormatter()
        f.timeStyle = .short
        return "\(f.string(from: event.start)) – \(f.string(from: event.end))"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(event.calendarColor.swiftUIColor)
                        .frame(width: 4, height: 34)
                    Text(event.title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(3)
                }

                detailRow(icon: "clock", text: dateRangeLabel)
                detailRow(icon: "calendar", text: event.calendarTitle)

                if let loc = event.location, !loc.isEmpty {
                    detailRow(icon: "mappin.and.ellipse", text: loc)
                    Text("Open on iPhone for directions")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.leading, 26)
                }

                Text(relativeLabel)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(WatchTheme.accent)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Event")
    }

    private func detailRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(WatchTheme.accent)
                .frame(width: 16)
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
            Spacer(minLength: 0)
        }
    }

    private var relativeLabel: String {
        let now = Date()
        if event.end < now { return "Ended" }
        if event.start <= now { return "Happening now" }
        let minutes = Int(event.start.timeIntervalSince(now) / 60)
        if minutes < 60 { return "Starts in \(minutes) min" }
        let hours = minutes / 60
        if hours < 24 { return "Starts in \(hours) hr" }
        return "Starts \(event.start.fmt("EEE, MMM d"))"
    }
}
