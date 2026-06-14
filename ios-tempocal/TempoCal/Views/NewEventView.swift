//
//  NewEventView.swift
//  TempoCal
//

import SwiftUI
import EventKit
import PhotosUI

/// Fantastical-style natural language event/reminder creation. Type a sentence and watch
/// the parsed event preview update live, with manual fine-tuning below.
/// Supports events, reminders, and recurring events.
struct NewEventView: View {
    @Bindable var store: EventStore
    @Bindable var reminderStore: ReminderStore
    var initialDate: Date
    /// Optional exact start time to pre-fill (used when tapping a free slot).
    var prefillStart: Date?
    let onDismiss: () -> Void

    @State private var phrase: String = ""
    @State private var parsed: ParsedEvent
    @State private var manualTitle: String = ""
    @State private var manualStart: Date
    @State private var manualEnd: Date
    @State private var manualAllDay: Bool = false
    @State private var manualCalendarColor: CalendarColor = CalendarColor.default
    @State private var manualLocation: String = ""
    @State private var hasEdited: Bool = false
    @State private var selectedCalendar: EKCalendar?
    @State private var isReminder: Bool = false
    @State private var isRecurring: Bool = false
    @State private var scanItem: PhotosPickerItem?
    @State private var isScanning: Bool = false
    @State private var scanError: String?
    @FocusState private var phraseFocused: Bool

    private let suggestions = [
        "Lunch with Sam tomorrow at noon",
        "Gym Friday 7am for 1 hour",
        "Remind me to buy groceries tomorrow",
        "Team standup every Monday at 9am",
        "Coffee with Alex Thursday 3pm at Blue Bottle"
    ]
    private let reminderSuggestions = [
        "Remind me to call mom tomorrow",
        "Remind me to review the budget",
        "Remind me to order supplies Friday"
    ]

    init(store: EventStore, reminderStore: ReminderStore, initialDate: Date, prefillStart: Date? = nil, onDismiss: @escaping () -> Void) {
        self.store = store
        self.reminderStore = reminderStore
        self.initialDate = initialDate
        self.prefillStart = prefillStart
        self.onDismiss = onDismiss
        let seed = prefillStart ?? (Calendar.app.date(bySettingHour: 9, minute: 0, second: 0, of: initialDate) ?? initialDate)
        _manualStart = State(initialValue: seed)
        _manualEnd = State(initialValue: seed.addingTimeInterval(3600))
        _parsed = State(initialValue: ParsedEvent(title: "", start: seed, end: seed.addingTimeInterval(3600), isAllDay: false, location: nil, palette: .coral, isReminder: false, recurrenceRule: nil, hasTimeComponent: false))
        _selectedCalendar = State(initialValue: store.calendars.first)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    naturalLanguageField
                    if !isReminder {
                        scanRow
                    }
                    if !hasEdited && phrase.isEmpty {
                        if !isReminder {
                            quickAddTemplates
                        }
                        suggestionChips
                    }
                    if isReminder || isRecurring {
                        typeIndicators
                    }
                    previewCard
                    if !isReminder {
                        conflictBanner
                    }
                    detailForm
                }
                .padding(16)
                .padding(.bottom, 40)
            }
            .background(Theme.background)
            .navigationTitle(isReminder ? "New Reminder" : "New Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDismiss() }
                        .foregroundStyle(Theme.inkSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { save() }
                        .fontWeight(.bold)
                        .foregroundStyle(Theme.accent)
                        .disabled(currentTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .onAppear { phraseFocused = true }
    }

    // MARK: - Natural language

    private var naturalLanguageField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: isReminder ? "checklist" : "wand.and.stars")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isReminder ? Color(hex: 0x2E9CDB) : Theme.accent)
                TextField(isReminder ? "Remind me to call Mom tomorrow" : "Lunch with Maya Friday at 1pm",
                          text: $phrase, axis: .vertical)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Theme.ink)
                    .focused($phraseFocused)
                    .submitLabel(.done)
                    .onChange(of: phrase) { _, newValue in
                        guard !newValue.isEmpty else { return }
                        applyParse(newValue)
                    }
            }
            .padding(16)
            .background(Theme.surface)
            .clipShape(.rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isReminder ? Color(hex: 0x2E9CDB).opacity(0.3) : Theme.accentSoft, lineWidth: 1.5)
            )

            // Quick toggle: Event vs Reminder
            HStack(spacing: 8) {
                typeToggleButton("Event", icon: "calendar", isActive: !isReminder) {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    isReminder = false
                    hasEdited = true
                }
                typeToggleButton("Reminder", icon: "checklist", isActive: isReminder) {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    isReminder = true
                    manualAllDay = false
                    hasEdited = true
                }
            }
        }
    }

    private func typeToggleButton(_ title: String, icon: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(isActive ? .white : Theme.inkSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isActive ? AnyShapeStyle(Theme.sunset) : AnyShapeStyle(Theme.surface))
            )
            .overlay(
                Capsule()
                    .stroke(isActive ? Color.clear : Theme.hairline, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var typeIndicators: some View {
        HStack(spacing: 8) {
            if isReminder {
                Label("Reminder", systemImage: "checklist")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x2E9CDB))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(hex: 0x2E9CDB).opacity(0.1))
                    .clipShape(Capsule())
            }
            if isRecurring, let rule = parsed.recurrenceRule {
                Label(recurrenceLabel(rule), systemImage: "repeat")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Theme.accentSoft)
                    .clipShape(Capsule())
            }
        }
    }

    private func recurrenceLabel(_ rule: RecurrencePattern) -> String {
        switch rule.frequency {
        case .daily: return "Daily"
        case .weekly: return rule.interval == 2 ? "Every 2 weeks" : "Weekly"
        case .biweekly: return "Every 2 weeks"
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        }
    }

    private var suggestionChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(isReminder ? reminderSuggestions : suggestions, id: \.self) { suggestion in
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        phrase = suggestion
                        applyParse(suggestion)
                    } label: {
                        Text(suggestion)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Theme.inkSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Theme.surface)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Theme.hairline, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
        }
        .contentMargins(.horizontal, 0)
    }

    // MARK: - Photo-to-event (OCR)

    private var scanRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            PhotosPicker(selection: $scanItem, matching: .images, photoLibrary: .shared()) {
                HStack(spacing: 9) {
                    if isScanning {
                        ProgressView()
                            .controlSize(.small)
                            .tint(Theme.accent)
                    } else {
                        Image(systemName: "text.viewfinder")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                    }
                    Text(isScanning ? "Reading photo…" : "Scan a flyer or screenshot")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Spacer(minLength: 0)
                    if !isScanning {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Theme.accent.opacity(0.7))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Theme.accentSoft.opacity(0.45))
                .clipShape(.rect(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.accentSoft, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(isScanning)
            .onChange(of: scanItem) { _, item in
                guard let item else { return }
                Task { await scanPhoto(item) }
            }

            if let scanError {
                Text(scanError)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.inkSecondary)
                    .padding(.leading, 4)
            }
        }
    }

    /// Loads the picked image, OCRs it on-device, then feeds the text into the NLP parser.
    private func scanPhoto(_ item: PhotosPickerItem) async {
        isScanning = true
        scanError = nil
        defer {
            isScanning = false
            scanItem = nil
        }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                scanError = "Couldn't load that image."
                return
            }
            let text = try await EventImageScanner.recognizeText(in: data)
            applyScannedText(text)
        } catch {
            scanError = error.localizedDescription
        }
    }

    /// Condenses recognized lines into a single phrase and parses it into the live preview.
    private func applyScannedText(_ raw: String) {
        let condensed = raw
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .prefix(8)
            .joined(separator: " ")
        let trimmed = String(condensed.prefix(180))
        guard !trimmed.isEmpty else {
            scanError = "No readable text found in that image."
            return
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        phraseFocused = false
        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
            hasEdited = false
            manualTitle = ""
            phrase = trimmed
            applyParse(trimmed)
        }
    }

    // MARK: - Quick Add Templates

    private var quickAddTemplates: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("QUICK ADD")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.inkTertiary)
                .padding(.leading, 4)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(EventTemplate.defaults) { template in
                        Button {
                            applyTemplate(template)
                        } label: {
                            HStack(spacing: 7) {
                                Image(systemName: template.icon)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(Color(hex: template.colorHex))
                                    .frame(width: 26, height: 26)
                                    .background(Color(hex: template.colorHex).opacity(0.14))
                                    .clipShape(Circle())
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(template.name)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Theme.ink)
                                    Text(durationLabel(template.durationMinutes))
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(Theme.inkTertiary)
                                }
                            }
                            .padding(.leading, 6)
                            .padding(.trailing, 12)
                            .padding(.vertical, 6)
                            .background(Theme.surface)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Theme.hairline, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2)
            }
            .contentMargins(.horizontal, 0)
        }
    }

    private func durationLabel(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) min" }
        let h = Double(minutes) / 60.0
        return h == floor(h) ? "\(Int(h)) hr" : String(format: "%.1f hr", h)
    }

    /// Pre-fills the form from a quick-add template, snapping to the next half hour.
    private func applyTemplate(_ template: EventTemplate) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let start = snappedStart(from: prefillStart ?? manualStart)
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            manualTitle = template.name
            manualStart = start
            manualEnd = start.addingTimeInterval(TimeInterval(template.durationMinutes * 60))
            manualAllDay = false
            if let location = template.location { manualLocation = location }
            isReminder = false
            hasEdited = true
        }
    }

    /// Rounds a date up to the next 30-minute boundary for tidy quick-add times.
    private func snappedStart(from date: Date) -> Date {
        let cal = Calendar.app
        let minute = cal.component(.minute, from: date)
        let remainder = minute % 30
        guard remainder != 0 else { return date }
        return cal.date(byAdding: .minute, value: 30 - remainder, to: date) ?? date
    }

    // MARK: - Preview

    private var previewCard: some View {
        let color = selectedCalendar.map { CalendarColor(cgColor: $0.cgColor).swiftUIColor } ?? Theme.accent

        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                if isReminder {
                    Image(systemName: "checklist")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color(hex: 0x2E9CDB))
                } else {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: 6, height: 44)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(currentTitle.isEmpty ? (isReminder ? "New Reminder" : "New Event") : currentTitle)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(currentTitle.isEmpty ? Theme.inkTertiary : Theme.ink)
                        .lineLimit(1)
                    Text(previewSubtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.inkSecondary)
                }
                Spacer()
            }
            .padding(16)
        }
        .background(
            LinearGradient(
                colors: [color.opacity(0.10), color.opacity(0.04)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .clipShape(.rect(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(color.opacity(0.25), lineWidth: 1))
    }

    // MARK: - Conflict detection

    /// Timed events on the chosen day that overlap the proposed time range.
    private var conflicts: [CalendarEvent] {
        guard !isReminder, !manualAllDay else { return [] }
        return ScheduleAnalyzer.conflicts(
            start: manualStart,
            end: manualEnd,
            among: store.events,
            on: manualStart
        )
    }

    /// Open slots on the chosen day, long enough to fit the proposed event.
    private var suggestedSlots: [FreeSlot] {
        let needed = max(15, Int(manualEnd.timeIntervalSince(manualStart) / 60))
        return ScheduleAnalyzer.freeSlots(on: manualStart, events: store.events, minMinutes: needed)
    }

    @ViewBuilder
    private var conflictBanner: some View {
        if !conflicts.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color(hex: 0xE08A2B))
                    Text(conflicts.count == 1 ? "Overlaps 1 event" : "Overlaps \(conflicts.count) events")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                }
                ForEach(conflicts.prefix(3)) { event in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(event.calendarColor.swiftUIColor)
                            .frame(width: 7, height: 7)
                        Text(event.title)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Theme.inkSecondary)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        Text(event.timeRangeLabel)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.inkTertiary)
                    }
                }

                if !suggestedSlots.isEmpty {
                    Text("TAP A FREE SLOT TO RESCHEDULE")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.inkTertiary)
                        .padding(.top, 2)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(suggestedSlots.prefix(4)) { slot in
                                Button {
                                    moveEvent(to: slot.start)
                                } label: {
                                    Text(slot.start.timeLabel)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Theme.accent)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 7)
                                        .background(Theme.accentSoft.opacity(0.7))
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .contentMargins(.horizontal, 0)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(hex: 0xE08A2B).opacity(0.08))
            .clipShape(.rect(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: 0xE08A2B).opacity(0.3), lineWidth: 1))
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    /// Shift the event to start at `newStart`, preserving its duration.
    private func moveEvent(to newStart: Date) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let duration = manualEnd.timeIntervalSince(manualStart)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            manualStart = newStart
            manualEnd = newStart.addingTimeInterval(duration > 0 ? duration : 3600)
            hasEdited = true
        }
    }

    private var previewSubtitle: String {
        if isReminder {
            let dayPart = manualStart.relativeDayLabel
            return "\(dayPart) · Reminder"
        }
        let dayPart = manualStart.relativeDayLabel
        if manualAllDay { return "\(dayPart) · All day" }
        let timePart = "\(manualStart.timeLabel) – \(manualEnd.timeLabel)"
        var s = "\(dayPart) · \(timePart)"
        if !manualLocation.isEmpty { s += " · \(manualLocation)" }
        if let cal = selectedCalendar { s += " · \(cal.title)" }
        return s
    }

    // MARK: - Manual form

    private var detailForm: some View {
        VStack(spacing: 14) {
            formField(icon: isReminder ? "checklist" : "textformat") {
                TextField("Title", text: Binding(
                    get: { currentTitle },
                    set: { manualTitle = $0; hasEdited = true }
                ))
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.ink)
            }

            if !isReminder {
                formField(icon: "mappin.and.ellipse") {
                    TextField("Location", text: $manualLocation)
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.ink)
                }
            }

            VStack(spacing: 0) {
                if !isReminder {
                    Toggle(isOn: $manualAllDay.animation()) {
                        Label("All day", systemImage: "sun.max")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Theme.ink)
                    }
                    .tint(Theme.accent)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)

                    Divider().background(Theme.hairline)
                }

                DatePicker(isReminder ? "Due" : "Starts",
                           selection: $manualStart,
                           displayedComponents: (isReminder || manualAllDay) ? [.date] : [.date, .hourAndMinute])
                    .font(.system(size: 15, weight: .medium))
                    .tint(Theme.accent)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 14)
                    .onChange(of: manualStart) { _, newValue in
                        if manualEnd <= newValue { manualEnd = newValue.addingTimeInterval(3600) }
                    }

                if !isReminder && !manualAllDay {
                    Divider().background(Theme.hairline)
                    DatePicker("Ends", selection: $manualEnd, in: manualStart..., displayedComponents: [.date, .hourAndMinute])
                        .font(.system(size: 15, weight: .medium))
                        .tint(Theme.accent)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 14)
                }
            }
            .background(Theme.surface)
            .clipShape(.rect(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.hairline, lineWidth: 1))

            calendarPicker
        }
    }

    private var calendarPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(isReminder ? "REMINDER LIST" : "CALENDAR")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.inkTertiary)
                .padding(.leading, 4)

            if store.isLive && !store.calendars.isEmpty {
                LazyVStack(spacing: 6) {
                    ForEach(store.calendars, id: \.calendarIdentifier) { calendar in
                        let color = CalendarColor(cgColor: calendar.cgColor)
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                selectedCalendar = calendar
                                manualCalendarColor = color
                                hasEdited = true
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(color.swiftUIColor)
                                    .frame(width: 14, height: 14)
                                Text(calendar.title)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Theme.ink)
                                Spacer(minLength: 0)
                                if selectedCalendar?.calendarIdentifier == calendar.calendarIdentifier {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(Theme.accent)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(
                                selectedCalendar?.calendarIdentifier == calendar.calendarIdentifier
                                    ? color.swiftUIColor.opacity(0.10)
                                    : Theme.surface
                            )
                            .clipShape(.rect(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        selectedCalendar?.calendarIdentifier == calendar.calendarIdentifier
                                            ? color.swiftUIColor
                                            : Theme.hairline,
                                        lineWidth: selectedCalendar?.calendarIdentifier == calendar.calendarIdentifier ? 1.5 : 1
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                Text("Calendar access not granted. Enable in Settings to choose a calendar.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.inkSecondary)
                    .padding(12)
            }
        }
    }

    private func formField<Content: View>(icon: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(Theme.inkTertiary)
                .frame(width: 20)
            content()
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.hairline, lineWidth: 1))
    }

    // MARK: - Logic

    private var currentTitle: String {
        manualTitle.isEmpty ? parsed.title : manualTitle
    }

    private func applyParse(_ text: String) {
        let result = NaturalLanguageEventParser.parse(text, reference: initialDate)
        parsed = result
        if !hasEdited {
            manualStart = result.start
            manualEnd = result.end
            manualAllDay = result.isAllDay
            manualLocation = result.location ?? ""
            isReminder = result.isReminder
            isRecurring = result.recurrenceRule != nil
        } else {
            isReminder = result.isReminder
            isRecurring = result.recurrenceRule != nil
        }
    }

    private func save() {
        let title = currentTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        if isReminder {
            let due = Calendar.app.isDateInToday(manualStart) ? manualStart : manualStart
            reminderStore.add(
                title: title,
                dueDate: due,
                to: selectedCalendar
            )
        } else {
            let event = CalendarEvent(
                title: title,
                start: manualStart,
                end: manualAllDay ? manualStart.endOfDay : manualEnd,
                isAllDay: manualAllDay,
                calendarColor: CalendarColor(cgColor: selectedCalendar?.cgColor ?? CGColor(red: 1, green: 0.353, blue: 0.302, alpha: 1)),
                calendarTitle: selectedCalendar?.title ?? "Calendar",
                location: manualLocation.isEmpty ? nil : manualLocation
            )
            store.add(event, to: selectedCalendar)
        }
        onDismiss()
    }
}
