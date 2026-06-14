//
//  ContentView.swift
//  TempoCal
//

import SwiftUI
import AppIntents
import EventKit
import CoreLocation
import UIKit

enum CalendarMode: String, CaseIterable, Identifiable {
    case day = "Day"
    case week = "Week"
    case month = "Month"
    case upcoming = "List"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .day: return "sun.max"
        case .week: return "calendar.day.timeline.left"
        case .month: return "calendar"
        case .upcoming: return "list.bullet"
        }
    }
}

struct ContentView: View {
    var premiumStore: PremiumStore
    @State private var store = EventStore()
    @State private var reminderStore = ReminderStore()
    @State private var mode: CalendarMode = .day
    @State private var selectedDate: Date = Date()
    @State private var visibleMonth: Date = Date().startOfMonth
    @State private var showingNew = false
    @State private var selectedEvent: CalendarEvent?
    @State private var showPermissionPrompt = false
    @State private var showCalendarSets = false
    @State private var showPaywall = false
    @State private var showSettings = false
    @State private var showSearch = false
    @State private var prefillSlotStart: Date?
    @State private var locationManager = LocationManager()
    @State private var notificationService = NotificationService()

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                modeSwitcher
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            addButton
        }
        .sheet(isPresented: $showingNew, onDismiss: { prefillSlotStart = nil }) {
            NewEventView(
                store: store,
                reminderStore: reminderStore,
                initialDate: selectedDate,
                prefillStart: prefillSlotStart
            ) {
                showingNew = false
            }
            .presentationDetents([.large])
        }
        .sheet(item: $selectedEvent) { event in
            EventDetailView(
                store: store,
                premiumStore: premiumStore,
                event: event,
                userLocation: locationManager.lastLocation
            ) {
                selectedEvent = nil
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showCalendarSets) {
            CalendarSetPicker(store: store)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(store: premiumStore)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(
                premiumStore: premiumStore,
                store: store,
                reminderStore: reminderStore,
                notificationService: notificationService
            )
        }
        .sheet(isPresented: $showSearch) {
            SearchView(store: store, reminderStore: reminderStore) { event in
                selectedEvent = event
            }
        }
        .onAppear {
            if !store.isLive && store.authorizationStatus != .fullAccess {
                showPermissionPrompt = true
            }
            TempoCalShortcuts.updateAppShortcutParameters()
            locationManager.requestLocation()
            Task { await requestRemindersIfNeeded() }
            Task { await notificationService.reschedule(events: store.events) }
        }
        .alert("Enable Calendar Access", isPresented: $showPermissionPrompt) {
            Button("Enable") { Task { _ = await store.requestAccess() } }
            Button("Don't Allow", role: .cancel) {}
        } message: {
            Text("ChronoSync needs access to your calendars to show and manage events.")
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(headerTitle)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(Theme.ink)
                    HStack(spacing: 8) {
                        Text(headerSubtitle)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Theme.accent)
                    }
                }
                Spacer()
                HStack(spacing: 6) {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showSearch = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Theme.inkSecondary)
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.plain)
                    CalendarSetsButton(count: visibleCalendarCount) {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        if premiumStore.isPremium {
                            showCalendarSets = true
                        } else {
                            showPaywall = true
                        }
                    }
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            selectedDate = Date()
                            visibleMonth = Date().startOfMonth
                        }
                    } label: {
                        Text("Today")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Theme.accentSoft.opacity(0.6))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showSettings = true
                    } label: {
                        Image(systemName: premiumStore.isPremium ? "person.crop.circle.fill" : "person.crop.circle")
                            .font(.system(size: 22, weight: .regular))
                            .foregroundStyle(premiumStore.isPremium ? Theme.accent : Theme.inkSecondary)
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 4)
        }
    }

    private var visibleCalendarCount: Int {
        store.isLive ? store.calendars.count : 2
    }

    private var headerTitle: String {
        switch mode {
        case .day: return selectedDate.formatted("EEEE")
        case .week: return "Week of \(selectedDate.startOfWeek.formatted("MMM d"))"
        case .month: return visibleMonth.formatted("MMMM")
        case .upcoming: return "Upcoming"
        }
    }

    private var headerSubtitle: String {
        switch mode {
        case .day: return selectedDate.formatted("MMMM d, yyyy")
        case .week: return selectedDate.formatted("yyyy")
        case .month: return visibleMonth.formatted("yyyy")
        case .upcoming: return "\(store.events.count) events scheduled"
        }
    }

    // MARK: - Mode switcher

    private var modeSwitcher: some View {
        HStack(spacing: 4) {
            ForEach(CalendarMode.allCases) { item in
                Button {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        mode = item
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: item.icon)
                            .font(.system(size: 13, weight: .semibold))
                        Text(item.rawValue)
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(mode == item ? .white : Theme.inkSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        ZStack {
                            if mode == item {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Theme.sunset)
                            }
                        }
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.hairline, lineWidth: 1))
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch mode {
        case .day:
            VStack(spacing: 0) {
                if selectedDate.isToday {
                    dailyBriefSection
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }
                DayTimelineView(
                    day: selectedDate,
                    events: store.events(on: selectedDate),
                    reminders: reminderStore.reminders(on: selectedDate)
                ) { selectedEvent = $0 }
            }
            .transition(.opacity)
        case .week:
            WeekView(
                store: store,
                reminderStore: reminderStore,
                selectedDate: $selectedDate
            ) { selectedEvent = $0 }
            .transition(.opacity)
        case .month:
            MonthView(
                store: store,
                reminderStore: reminderStore,
                selectedDate: $selectedDate,
                visibleMonth: $visibleMonth
            ) { selectedEvent = $0 }
            .gesture(monthSwipe)
            .transition(.opacity)
        case .upcoming:
            UpcomingView(store: store, reminderStore: reminderStore) {
                selectedEvent = $0
            }
            .transition(.opacity)
        }
    }

    // MARK: - Daily Brief

    @ViewBuilder
    private var dailyBriefSection: some View {
        if premiumStore.isPremium {
            DailyBriefView(
                day: selectedDate,
                events: store.events(on: selectedDate)
            ) { slot in
                prefillSlotStart = slot.start
                showingNew = true
            }
        } else {
            DailyBriefLockedCard {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showPaywall = true
            }
        }
    }

    private var monthSwipe: some Gesture {
        DragGesture(minimumDistance: 40)
            .onEnded { value in
                if value.translation.width < -40 {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        visibleMonth = visibleMonth.adding(months: 1)
                    }
                } else if value.translation.width > 40 {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        visibleMonth = visibleMonth.adding(months: -1)
                    }
                }
            }
    }

    // MARK: - Add button

    private var addButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            showingNew = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .background(Theme.sunset)
                .clipShape(Circle())
                .shadow(color: Theme.accent.opacity(0.4), radius: 14, x: 0, y: 8)
        }
        .buttonStyle(.plain)
        .padding(.trailing, 22)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func requestRemindersIfNeeded() async {
        if reminderStore.isAuthorized { return }
        _ = await reminderStore.requestAccess()
    }
}

// MARK: - Location Manager

final class LocationManager: NSObject, CLLocationManagerDelegate, @unchecked Sendable {
    private let manager = CLLocationManager()
    private(set) var lastLocation: CLLocation?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func requestLocation() {
        manager.requestWhenInUseAuthorization()
        manager.requestLocation()
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.lastLocation = location
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("[ChronoSync] Location error: \(error.localizedDescription)")
    }
}
