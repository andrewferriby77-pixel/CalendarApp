import WidgetKit
import SwiftUI

// MARK: - Entry

nonisolated struct ComplicationEntry: TimelineEntry {
    let date: Date
    let snapshot: ComplicationSnapshot
}

// MARK: - Provider

nonisolated struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> ComplicationEntry {
        ComplicationEntry(date: .now, snapshot: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (ComplicationEntry) -> Void) {
        completion(ComplicationEntry(date: .now, snapshot: SharedComplicationStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ComplicationEntry>) -> Void) {
        let snapshot = SharedComplicationStore.load()
        let now = Date()
        // Refresh again shortly so the "starts in" countdown stays fresh.
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: now) ?? now.addingTimeInterval(900)
        let entry = ComplicationEntry(date: now, snapshot: snapshot)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - Shared helpers

private let accent = Color(red: 1.0, green: 0.353, blue: 0.302)

private func eventColor(_ rgb: [Double]) -> Color {
    guard rgb.count >= 3 else { return accent }
    return Color(red: rgb[0], green: rgb[1], blue: rgb[2])
}

private func timeString(_ date: Date) -> String {
    let f = DateFormatter()
    f.timeStyle = .short
    return f.string(from: date)
}

// MARK: - Views per family

struct ComplicationView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ComplicationEntry

    var body: some View {
        if entry.snapshot.premiumActive {
            unlockedView
        } else {
            lockedView
        }
    }

    // Premium: live schedule glance

    @ViewBuilder
    private var unlockedView: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                if entry.snapshot.showsTomorrow {
                    VStack(spacing: 0) {
                        Text("TMRW")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(accent)
                        Text("\(entry.snapshot.tomorrowCount)")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .minimumScaleFactor(0.6)
                    }
                } else {
                    VStack(spacing: 0) {
                        Image(systemName: "calendar")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(accent)
                        Text("\(entry.snapshot.todayCount)")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .minimumScaleFactor(0.6)
                    }
                }
            }
        case .accessoryInline:
            if let title = entry.snapshot.nextTitle, let start = entry.snapshot.nextStart {
                Label("\(timeString(start)) · \(title)", systemImage: "calendar")
            } else if let title = entry.snapshot.tomorrowTitle, let start = entry.snapshot.tomorrowStart {
                Label("Tmrw \(timeString(start)) · \(title)", systemImage: "calendar")
            } else {
                Label("No more events", systemImage: "calendar")
            }
        case .accessoryCorner:
            Image(systemName: "calendar")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(accent)
                .widgetLabel {
                    if let start = entry.snapshot.nextStart {
                        Text(start, style: .time)
                    } else if let start = entry.snapshot.tomorrowStart {
                        Text("Tmrw \(timeString(start))")
                    } else {
                        Text("Clear")
                    }
                }
        default: // accessoryRectangular
            rectangularUnlocked
        }
    }

    private var rectangularUnlocked: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(eventColor(barColor))
                .frame(width: 4)
            VStack(alignment: .leading, spacing: 1) {
                if let title = entry.snapshot.nextTitle, let start = entry.snapshot.nextStart {
                    Text("UP NEXT")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(accent)
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(start, style: .time)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.secondary)
                } else if let title = entry.snapshot.tomorrowTitle, let start = entry.snapshot.tomorrowStart {
                    Text("TOMORROW")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(accent)
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(start, style: .time)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.secondary)
                } else {
                    Text("ChronoSync")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(accent)
                    Text("Nothing left today")
                        .font(.system(size: 17, weight: .semibold))
                        .minimumScaleFactor(0.8)
                    Text("\(entry.snapshot.todayCount) events total")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private var barColor: [Double] {
        entry.snapshot.showsTomorrow ? entry.snapshot.tomorrowColor : entry.snapshot.nextColor
    }

    // Locked: prompt to unlock premium

    @ViewBuilder
    private var lockedView: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "lock.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(accent)
            }
        case .accessoryInline:
            Label("Unlock ChronoSync Premium", systemImage: "lock.fill")
        case .accessoryCorner:
            Image(systemName: "lock.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(accent)
                .widgetLabel("Premium")
        default:
            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("ChronoSync Premium")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Unlock to see your schedule")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - Widget

struct ChronoSyncComplication: Widget {
    let kind: String = "ChronoSyncComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            ComplicationView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("ChronoSync")
        .description("Your next event, right on your watch face.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCorner
        ])
    }
}
