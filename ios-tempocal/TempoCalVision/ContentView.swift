import SwiftUI
import EventKit

/// A spatial calendar browser for Apple Vision Pro.
/// Uses visionOS-native glass materials and large, browseable layouts.
@main
struct TempoCalVisionApp: App {
    @State private var store = VisionEventStore()

    var body: some Scene {
        WindowGroup {
            VisionCalendarView(store: store)
                .frame(minWidth: 800, idealWidth: 1000, minHeight: 600, idealHeight: 700)
        }
        .windowStyle(.volumetric)
        .defaultSize(width: 1000, height: 700)

        WindowGroup(id: "day") {
            VisionDayView(store: store, date: Date())
                .frame(minWidth: 500, minHeight: 600)
        }
        .defaultSize(width: 500, height: 600)

        WindowGroup(id: "upcoming") {
            VisionUpcomingView(store: store)
                .frame(minWidth: 500, minHeight: 600)
        }
        .defaultSize(width: 500, height: 600)
    }
}

// MARK: - Vision Event Store

@Observable
final class VisionEventStore {
    private let ekStore = EKEventStore()
    private(set) var events: [CalendarEvent] = []
    private(set) var isAuthorized = false
    private(set) var selectedDate = Date()

    init() {
        let status = EKEventStore.authorizationStatus(for: .event)
        if status == .fullAccess || status == .writeOnly {
            isAuthorized = true
            refresh()
        }
    }

    func requestAccess() async {
        if #available(visionOS 2.0, *) {
            do {
                _ = try await ekStore.requestFullAccessToEvents()
                isAuthorized = true
                await MainActor.run { refresh() }
            } catch {
                isAuthorized = false
            }
        } else {
            let granted = try? await ekStore.requestAccess(to: .event)
            isAuthorized = granted == true
            if granted == true {
                await MainActor.run { refresh() }
            }
        }
    }

    func refresh() {
        guard isAuthorized else { return }
        let now = Date()
        let start = now.adding(days: -60)
        let end = now.adding(days: 365)
        let predicate = ekStore.predicateForEvents(withStart: start, end: end, calendars: nil)
        events = ekStore.events(matching: predicate).map { CalendarEvent(from: $0) }.sorted { $0.start < $1.start }
    }

    func events(on day: Date) -> [CalendarEvent] {
        events.filter { $0.occurs(on: day) }
            .sorted { $0.start < $1.start }
    }

    func hasEvents(on day: Date) -> Bool {
        events.contains { $0.occurs(on: day) }
    }

    func upcomingGrouped(limitDays: Int = 14) -> [(day: Date, events: [CalendarEvent])] {
        let start = Date().startOfDay
        var result: [(Date, [CalendarEvent])] = []
        for offset in 0..<limitDays {
            let day = start.adding(days: offset)
            let dayEvents = events(on: day)
            if !dayEvents.isEmpty {
                result.append((day, dayEvents))
            }
        }
        return result
    }
}

// MARK: - Main Calendar View

struct VisionCalendarView: View {
    @Bindable var store: VisionEventStore
    @State private var mode: VisionMode = .month

    enum VisionMode: String, CaseIterable {
        case day = "Day"
        case month = "Month"
    }

    var body: some View {
        NavigationSplitView {
            // Sidebar
            List(selection: $mode) {
                ForEach(VisionMode.allCases, id: \.self) { m in
                    Label(m.rawValue, systemImage: m == .day ? "sun.max" : "calendar")
                        .tag(m)
                }
            }
            .navigationTitle("ChronoSync")
            .toolbar {
                ToolbarItem {
                    if !store.isAuthorized {
                        Button("Enable Calendar") {
                            Task { await store.requestAccess() }
                        }
                    }
                }
            }
        } detail: {
            switch mode {
            case .day:
                VisionDayView(store: store, date: store.selectedDate)
            case .month:
                VisionMonthView(store: store, selectedDate: $store.selectedDate)
            }
        }
        .background(.regularMaterial)
    }
}

// MARK: - Day View

struct VisionDayView: View {
    @Bindable var store: VisionEventStore
    let date: Date

    private var dayEvents: [CalendarEvent] { store.events(on: date) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text(date.formatted("EEEE"))
                        .font(.system(size: 32, weight: .bold))
                    Text(date.formatted("MMMM d, yyyy"))
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("\(dayEvents.count) event\(dayEvents.count == 1 ? "" : "s")")
                        .font(.system(size: 14))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 24)

                Divider()
                    .padding(.horizontal, 32)

                // Timeline
                if dayEvents.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "sun.max")
                            .font(.system(size: 40))
                            .foregroundStyle(.tertiary)
                        Text("Nothing planned")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 80)
                } else {
                    VStack(spacing: 12) {
                        ForEach(dayEvents) { event in
                            visionEventCard(event)
                        }
                    }
                    .padding(32)
                }
            }
        }
    }

    private func visionEventCard(_ event: CalendarEvent) -> some View {
        HStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 4)
                .fill(event.calendarColor.swiftUIColor)
                .frame(width: 6, height: 52)

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.system(size: 20, weight: .semibold))
                    .lineLimit(2)
                HStack(spacing: 8) {
                    Text(event.timeRangeLabel)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                    if let loc = event.location {
                        Text("·")
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 12))
                        Text(loc)
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            Spacer()
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 20))
    }
}

// MARK: - Month View

struct VisionMonthView: View {
    @Bindable var store: VisionEventStore
    @Binding var selectedDate: Date
    @State private var visibleMonth: Date = Date().startOfMonth

    private let hourLabels = ["12 AM", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "Noon", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11"]

    var body: some View {
        VStack(spacing: 0) {
            // Month navigator
            HStack {
                Button {
                    visibleMonth = visibleMonth.adding(months: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                }
                .buttonStyle(.borderless)

                Text(visibleMonth.formatted("MMMM yyyy"))
                    .font(.system(size: 28, weight: .bold))
                    .frame(maxWidth: .infinity)

                Button {
                    visibleMonth = visibleMonth.adding(months: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.title2)
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 16)

            Divider()
                .padding(.horizontal, 32)

            // Weekday headers
            HStack {
                ForEach(["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], id: \.self) { day in
                    Text(day)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 12)

            // Grid
            let days = daysInGrid(for: visibleMonth)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 6) {
                ForEach(days, id: \.self) { day in
                    dayCell(day)
                }
            }
            .padding(.horizontal, 28)
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let inMonth = Calendar.app.isDate(day, equalTo: visibleMonth, toGranularity: .month)
        let isSelected = day.isSameDay(as: selectedDate)
        let hasEvents = store.hasEvents(on: day)

        return Button {
            selectedDate = day
        } label: {
            VStack(spacing: 4) {
                Text("\(day.dayNumber)")
                    .font(.system(size: 16, weight: day.isToday ? .bold : .medium))
                    .foregroundStyle(isSelected ? .white : (inMonth ? .primary : .tertiary))
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(isSelected ? Color.accentColor : Color.clear)
                    )
                    .overlay(
                        Circle()
                            .stroke(day.isToday && !isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                    )

                Circle()
                    .fill(hasEvents ? Color.accentColor : Color.clear)
                    .frame(width: 5, height: 5)
                    .opacity(hasEvents ? 1 : 0)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .buttonStyle(.borderless)
    }

    private func daysInGrid(for month: Date) -> [Date] {
        let firstOfMonth = month.startOfMonth
        let gridStart = firstOfMonth.startOfWeek
        return (0..<42).map { gridStart.adding(days: $0) }
    }
}

// MARK: - Upcoming View

struct VisionUpcomingView: View {
    @Bindable var store: VisionEventStore

    var body: some View {
        let groups = store.upcomingGrouped()
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Upcoming")
                    .font(.system(size: 32, weight: .bold))
                    .padding(.horizontal, 32)
                    .padding(.top, 24)

                if groups.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 40))
                            .foregroundStyle(.tertiary)
                        Text("Your schedule is clear")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 80)
                } else {
                    ForEach(groups, id: \.day) { group in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(dayLabel(group.day))
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(group.day.isToday ? Color.accentColor : .primary)
                                .padding(.horizontal, 32)

                            ForEach(group.events) { event in
                                upcomingCard(event)
                                    .padding(.horizontal, 32)
                            }
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
        }
    }

    private func upcomingCard(_ event: CalendarEvent) -> some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 3)
                .fill(event.calendarColor.swiftUIColor)
                .frame(width: 5)

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.system(size: 18, weight: .semibold))
                    .lineLimit(1)
                Text(event.timeRangeLabel)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 16))
    }

    private func dayLabel(_ day: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(day) { return "Today" }
        if cal.isDateInTomorrow(day) { return "Tomorrow" }
        return day.formatted("EEEE, MMM d")
    }
}
