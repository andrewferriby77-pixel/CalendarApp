//
//  EventShareCard.swift
//  TempoCal
//

import SwiftUI

/// A beautiful, share-ready card representation of an event.
/// Rendered to an image via ImageRenderer for sharing to Messages, Mail, social, etc.
struct EventShareCard: View {
    let event: CalendarEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header band
            HStack(spacing: 10) {
                Image(systemName: "calendar")
                    .font(.system(size: 16, weight: .bold))
                Text("ChronoSync")
                    .font(.system(size: 16, weight: .bold))
                Spacer()
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 28)
            .padding(.vertical, 22)
            .frame(maxWidth: .infinity)
            .background(Theme.sunset)

            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(event.calendarColor.swiftUIColor)
                            .frame(width: 12, height: 12)
                        Text(event.calendarTitle.uppercased())
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Theme.inkSecondary)
                    }
                    Text(event.title)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }

                infoRow(icon: "calendar", text: event.start.formatted("EEEE, MMMM d, yyyy"))
                infoRow(icon: "clock", text: event.isAllDay ? "All day" : "\(event.start.timeLabel) – \(event.end.timeLabel)")
                if let location = event.location, !location.isEmpty {
                    infoRow(icon: "mappin.and.ellipse", text: location)
                }

                Text("Shared from ChronoSync")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.inkTertiary)
                    .padding(.top, 4)
            }
            .padding(28)
        }
        .frame(width: 380)
        .background(Theme.surface)
    }

    private func infoRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 24)
            Text(text)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}
