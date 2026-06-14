# ChronoSync — Fantastical-Style Calendar

## Features

- [x] **Real Calendar Sync (EventKit)** — Reads and writes directly to iPhone's built-in calendars (iCloud, Google, Exchange). Real calendar colors. Event creation, editing, and deletion.
- [x] **Siri & Shortcuts** — Create events hands-free with Siri. Appears in Shortcuts app and Spotlight.
- [x] **Apple Watch** — Today's schedule with up-next card, upcoming view, beautiful dark theme. Dictate new events from the wrist (created on the paired iPhone) and tap any event for a detail screen with time, calendar, location, and a live countdown.
- [x] **Watch Complications (Premium)** — Circular, rectangular, inline, and corner watch-face complications showing your next event and today's count. Once today is clear, they automatically roll over to preview tomorrow's first event and count (TOMORROW / Tmrw labels). Gated behind ChronoSync Premium — status syncs from the iPhone via WatchConnectivity; locked complications prompt to unlock.
- [x] **Apple Vision Pro** — Spatial calendar windows with glass panels. Day, Month, and Upcoming views.
- [x] **Weather Integration (WeatherKit)** — 7-day forecast strip on day view. Weather emoji + temps on month cells. Precip chance indicators. Location-aware.
- [x] **Tasks & Reminders** — Apple Reminders shown alongside calendar events. Toggle completions. Create reminders via natural language. Priority indicators.
- [x] **Interactive Widgets** — Today widget (small + medium) with current events. Upcoming widget (medium + large) with multi-day forecast. Lock Screen circular and rectangular.
- [x] **Calendar Sets** — Toggle groups of calendars on/off (Work, Personal, Health, Travel). Individual calendar toggles. Smart auto-grouping.
- [x] **Enhanced NLP** — Parse reminders ("remind me to buy milk"), recurring events ("every Monday at 9am"), biweekly/monthly/yearly patterns. Smarter duration and location detection.
- [x] **Haptic Feedback** — Delightful micro-interactions on mode switches, event creation, date selection, calendar toggling, and deletions.
- [x] **ChronoSync Premium (one-time purchase)** — A single £10 unlock via RevenueCat. Premium unlocks the weather strip and snippets, Calendar Sets, and the full cross-device experience. Crown shortcut + paywall with restore purchases.
- [x] **Search** — Full-text search across events (title, location, notes) and reminders, grouped into Upcoming and Earlier. Tap a result to open it.
- [x] **Join Video Call** — Detects Zoom, Meet, Teams, Webex and other meeting links in an event and surfaces a one-tap join button.
- [x] **Get Directions** — Tap a physical event location to open Apple Maps with driving directions.
- [x] **Daily Brief (Premium)** — Morning summary card on today's view: warm greeting, next-event live countdown, weather, load stats, and tappable open-slot suggestions that pre-fill a new event. Free users see a locked teaser that opens the paywall.
- [x] **Conflict Detection** — Creating an event that overlaps existing ones surfaces a warning listing the clashes, plus one-tap free-slot chips to reschedule (preserving duration).
- [x] **Event Sharing (Premium)** — Share any event as a beautiful branded image card via the system share sheet. Free users are prompted to upgrade.
- [x] **Open Slot Discovery** — ScheduleAnalyzer finds free gaps in the waking window, powering both Daily Brief suggestions and conflict-aware rescheduling.
- [x] **Connected Accounts** — Connected Accounts screen lists every calendar account EventKit can see (iCloud, Google, Exchange / Office 365, Subscribed, On-device), grouped by provider with per-calendar visibility toggles. A guided Add Account sheet explains each provider with step-by-step instructions and deep-links to iOS Settings; sources auto-refresh on return.
- [x] **Quick-Add Templates** — One-tap chips (Standup, Lunch, Gym, Coffee, Focus block, Call) in New Event that instantly pre-fill the title and duration, snapping to the next half hour. Free, fast event entry.
- [x] **Travel Time & Leave-by Alerts (Premium)** — On Event Detail, ChronoSync geocodes a physical location and uses MapKit to show the driving time and the exact "Leave by" time to arrive on schedule (turns to "Leave now" when it's time). Free users see an upgrade teaser.
- [x] **Evening Digest (Premium)** — An opt-in nightly local notification that previews tomorrow's schedule (event count + first event), with a configurable delivery time. Auto-reschedules the next 7 evenings with real event data.
- [x] **Today Load Ring** — The Daily Brief shows an animated load ring visualizing how booked the waking day is (busy vs free), color-coded from "Wide open" to "Packed", alongside compact event/free-time/timed stats.
- [x] **Photo-to-Event (OCR)** — In New Event, tap "Scan a flyer or screenshot" to pick an image; on-device Vision OCR extracts the text and feeds it through the natural-language parser to pre-fill title, date, time, and location in the live preview.

## Design

Warm editorial palette — cream backgrounds, sunset coral accents, rich ink text. Real calendar colors from EventKit. Weather emoji and forecast data woven into calendar cells. Glass-style cards with subtle shadows and hairline borders.

## Screens

- Day Timeline — vertical hour grid with positioned event blocks, reminders strip, weather forecast
- Week View — 7-day pill strip + day timeline
- Month Grid — calendar grid with event dots, weather emoji, and agenda below
- Upcoming List — events grouped by day, tasks section, Siri tip
- New Event/Reminder — natural language input with live preview, event/reminder toggle, recurrence detection
- Calendar Sets — bottom sheet picker for toggling calendar visibility
- Event Detail — full event view with Join Video Call, Get Directions, and delete confirmation
- Search — full-text search over events and reminders with grouped results
- Daily Brief — premium morning summary card atop today's Day view with next-event countdown and open-slot chips
- Event Share Card — a polished, branded image rendering of an event for sharing
- Watch Event Detail — tap-through screen showing time range, calendar, location, and a live "starts in" countdown
- Watch Dictation — toolbar + button opens dictation to create an event by voice from the wrist
- Connected Accounts — provider-grouped list of connected calendar accounts with per-calendar toggles, plus a guided Add Account sheet (iCloud, Google, Exchange, Office 365) linking to iOS Settings
