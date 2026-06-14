//
//  CalendarSetPicker.swift
//  TempoCal
//

import SwiftUI
import EventKit

/// A bottom sheet that lets users toggle calendar sets and individual calendars on/off.
struct CalendarSetPicker: View {
    @Bindable var store: EventStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // Calendar sets section
                Section {
                    ForEach(store.calendarSets) { set in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                store.toggleSet(set.name)
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: setImageName(set.name))
                                    .font(.system(size: 16))
                                    .foregroundStyle(set.isEnabled ? setTintColor(set.name) : Theme.inkTertiary)
                                    .frame(width: 24)
                                Text(set.name)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(Theme.ink)
                                Spacer()
                                if set.isEnabled {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(Theme.accent)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("CALENDAR SETS")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.inkTertiary)
                }

                // Individual calendars section
                if store.isLive && !store.allCalendars.isEmpty {
                    Section {
                        ForEach(store.allCalendars, id: \.calendarIdentifier) { cal in
                            let color = CalendarColor(cgColor: cal.cgColor)
                            let isHidden = store.isCalendarHidden(cal.calendarIdentifier)
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                    store.toggleCalendar(cal.calendarIdentifier)
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(color.swiftUIColor)
                                        .frame(width: 14, height: 14)
                                    Text(cal.title)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(isHidden ? Theme.inkTertiary : Theme.ink)
                                    Spacer()
                                    if !isHidden {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundStyle(Theme.accent)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        Text("CALENDARS")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.inkTertiary)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Calendars")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.accent)
                }
            }
        }
    }

    private func setImageName(_ name: String) -> String {
        switch name.lowercased() {
        case "all calendars": return "calendar"
        case "work": return "briefcase.fill"
        case "personal": return "person.fill"
        case "health": return "heart.fill"
        case "travel": return "airplane"
        case "social": return "person.2.fill"
        default: return "calendar"
        }
    }

    private func setTintColor(_ name: String) -> Color {
        switch name.lowercased() {
        case "work": return Color(hex: 0x2E9CDB)
        case "personal": return Theme.accent
        case "health": return Color(hex: 0x35A98C)
        case "travel": return Color(hex: 0xF0A93B)
        case "social": return Color(hex: 0x8B5CF6)
        default: return Theme.accent
        }
    }
}

/// Tappable button that opens the calendar set picker.
struct CalendarSetsButton: View {
    let count: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 5) {
                Image(systemName: "calendar")
                    .font(.system(size: 13, weight: .medium))
                Text("\(count) calendar\(count == 1 ? "" : "s")")
                    .font(.system(size: 13, weight: .medium))
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundStyle(Theme.inkSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Theme.surface)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Theme.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
