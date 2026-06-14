//
//  DailyBriefView.swift
//  TempoCal
//

import SwiftUI
import UIKit
import Combine

/// A premium "daily brief" card shown at the top of today's Day view.
/// Surfaces a warm greeting, the next event with a live countdown, today's load,
/// and tappable open-slot suggestions.
struct DailyBriefView: View {
    let day: Date
    let events: [CalendarEvent]
    /// Called when the user taps a free slot — pre-fills a new event at that time.
    var onPickSlot: (FreeSlot) -> Void

    @State private var now = Date()
    @State private var animatedLoad: Double = 0
    private let ticker = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    private var timedEvents: [CalendarEvent] {
        events.filter { !$0.isAllDay }.sorted { $0.start < $1.start }
    }

    private var nextEvent: CalendarEvent? {
        timedEvents.first { $0.end > now }
    }

    private var freeSlots: [FreeSlot] {
        ScheduleAnalyzer.freeSlots(on: day, events: events, minMinutes: 45)
            .filter { $0.end > now }
    }

    private var freeMinutes: Int {
        ScheduleAnalyzer.totalFreeMinutes(on: day, events: events)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            nextEventRow
            loadSection
            if !freeSlots.isEmpty {
                slotSuggestions
            }
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [Theme.accent.opacity(0.12), Theme.accent.opacity(0.03)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.accentSoft, lineWidth: 1))
        .shadow(color: Theme.accent.opacity(0.08), radius: 12, x: 0, y: 6)
        .onReceive(ticker) { now = $0 }
        .onAppear {
            withAnimation(.easeOut(duration: 0.9).delay(0.15)) { animatedLoad = loadFraction }
        }
        .onChange(of: loadFraction) { _, newValue in
            withAnimation(.easeOut(duration: 0.6)) { animatedLoad = newValue }
        }
    }

    // MARK: - Load ring + stats

    /// Fraction of the waking window (8am–10pm) already booked with timed events.
    private var loadFraction: Double {
        let window = Double((ScheduleAnalyzer.dayEndHour - ScheduleAnalyzer.dayStartHour) * 60)
        guard window > 0 else { return 0 }
        return min(1, Double(ScheduleAnalyzer.busyMinutes(on: day, events: events)) / window)
    }

    private var loadColor: Color {
        switch loadFraction {
        case ..<0.34: return Color(hex: 0x35A98C)
        case ..<0.7: return Color(hex: 0xF0A93B)
        default: return Theme.accent
        }
    }

    private var loadLabel: String {
        switch loadFraction {
        case 0: return "Wide open"
        case ..<0.34: return "Light day"
        case ..<0.7: return "Balanced"
        default: return "Packed"
        }
    }

    private var loadSection: some View {
        HStack(spacing: 16) {
            loadRing
            VStack(alignment: .leading, spacing: 8) {
                compactStat(icon: "calendar", value: "\(events.count)", label: events.count == 1 ? "event today" : "events today")
                compactStat(icon: "clock", value: freeTimeValue, label: "free time")
                compactStat(icon: "bolt.fill", value: "\(timedEvents.count)", label: timedEvents.count == 1 ? "timed event" : "timed events")
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Theme.surfaceElevated)
        .clipShape(.rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.hairline, lineWidth: 1))
    }

    private var loadRing: some View {
        ZStack {
            Circle()
                .stroke(Theme.hairline, lineWidth: 9)
            Circle()
                .trim(from: 0, to: animatedLoad)
                .stroke(loadColor, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 1) {
                Text("\(Int((loadFraction * 100).rounded()))%")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.numericText())
                Text(loadLabel.uppercased())
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(loadColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(width: 78, height: 78)
    }

    private func compactStat(icon: String, value: String, label: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 16)
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.ink)
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.inkTertiary)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: greetingIcon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.accent)
                    Text(greeting)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(Theme.ink)
                }
                Text(summaryLine)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.inkSecondary)
            }
            Spacer()
        }
    }

    // MARK: - Next event

    @ViewBuilder
    private var nextEventRow: some View {
        if let event = nextEvent {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(event.calendarColor.swiftUIColor)
                    .frame(width: 5, height: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text("UP NEXT")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.inkTertiary)
                    Text(event.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                }
                Spacer()
                Text(countdownLabel(to: event))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Theme.accentSoft.opacity(0.7))
                    .clipShape(Capsule())
            }
            .padding(12)
            .background(Theme.surfaceElevated)
            .clipShape(.rect(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.hairline, lineWidth: 1))
        } else {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                Text("Nothing left on the schedule — enjoy your day.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.inkSecondary)
                Spacer()
            }
            .padding(12)
            .background(Theme.surfaceElevated)
            .clipShape(.rect(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.hairline, lineWidth: 1))
        }
    }

    // MARK: - Free slot suggestions

    private var slotSuggestions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("OPEN SLOTS")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Theme.inkTertiary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(freeSlots.prefix(4)) { slot in
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            onPickSlot(slot)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 12, weight: .bold))
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(slot.rangeLabel)
                                        .font(.system(size: 12, weight: .semibold))
                                    Text(slot.durationLabel)
                                        .font(.system(size: 10, weight: .medium))
                                        .opacity(0.7)
                                }
                            }
                            .foregroundStyle(Theme.accent)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Theme.accentSoft.opacity(0.6))
                            .clipShape(.rect(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .contentMargins(.horizontal, 0)
        }
    }

    // MARK: - Helpers

    private var greeting: String {
        let hour = Calendar.app.component(.hour, from: now)
        switch hour {
        case 0..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    private var greetingIcon: String {
        let hour = Calendar.app.component(.hour, from: now)
        switch hour {
        case 0..<12: return "sunrise.fill"
        case 12..<17: return "sun.max.fill"
        default: return "moon.stars.fill"
        }
    }

    private var summaryLine: String {
        if events.isEmpty { return "Your day is wide open." }
        let count = events.count
        return "\(count) \(count == 1 ? "thing" : "things") on your plate today."
    }

    private var freeTimeValue: String {
        let h = freeMinutes / 60
        let m = freeMinutes % 60
        if h == 0 { return "\(m)m" }
        if m == 0 { return "\(h)h" }
        return "\(h)h \(m)m"
    }

    private func countdownLabel(to event: CalendarEvent) -> String {
        if event.start <= now && event.end > now { return "Now" }
        let minutes = Int(event.start.timeIntervalSince(now) / 60)
        if minutes < 1 { return "Now" }
        if minutes < 60 { return "in \(minutes)m" }
        let hours = minutes / 60
        let mins = minutes % 60
        if hours < 24 {
            return mins == 0 ? "in \(hours)h" : "in \(hours)h \(mins)m"
        }
        return event.start.timeLabel
    }
}

/// Compact locked teaser shown to free users in place of the Daily Brief.
struct DailyBriefLockedCard: View {
    var onUnlock: () -> Void

    var body: some View {
        Button(action: onUnlock) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.2))
                        .frame(width: 44, height: 44)
                    Image(systemName: "sparkles")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Daily Brief")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Your morning summary, next event countdown & open slots.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "lock.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(Theme.sunset)
            .clipShape(.rect(cornerRadius: 18))
            .shadow(color: Theme.accent.opacity(0.3), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }
}
