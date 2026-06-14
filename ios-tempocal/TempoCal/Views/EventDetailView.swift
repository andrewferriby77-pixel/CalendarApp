//
//  EventDetailView.swift
//  TempoCal
//

import SwiftUI
import UIKit
import MapKit
import CoreLocation

/// Detailed view of a single event with edit, delete, and haptic actions.
struct EventDetailView: View {
    @Bindable var store: EventStore
    var premiumStore: PremiumStore
    let event: CalendarEvent
    /// Current user location, used to estimate travel time to physical event locations.
    var userLocation: CLLocation? = nil
    let onDismiss: () -> Void

    @State private var showDeleteConfirmation = false
    @State private var shareImage: Image?
    @State private var showPaywall = false

    /// First video-meeting link discovered in the event's location or notes.
    private var meetingURL: URL? {
        MeetingLinkDetector.firstMeetingURL(in: [event.location, event.notes])
    }

    /// A real-world (non-URL) location we can route to, for upcoming timed events.
    private var routableLocation: String? {
        guard let location = event.location, !location.isEmpty,
              !MeetingLinkDetector.isLikelyURL(location),
              !event.isAllDay,
              event.start > Date() else { return nil }
        return location
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Color strip
                    RoundedRectangle(cornerRadius: 4)
                        .fill(event.calendarColor.swiftUIColor)
                        .frame(height: 6)
                        .frame(maxWidth: .infinity)

                    // Title
                    Text(event.title)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(Theme.ink)

                    // Calendar
                    HStack(spacing: 8) {
                        Circle()
                            .fill(event.calendarColor.swiftUIColor)
                            .frame(width: 12, height: 12)
                        Text(event.calendarTitle)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Theme.inkSecondary)
                    }

                    // Time
                    VStack(alignment: .leading, spacing: 6) {
                        detailRow(icon: "clock", label: "Time") {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.start.formatted("EEEE, MMMM d, yyyy"))
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Theme.ink)
                                if event.isAllDay {
                                    Text("All day")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Theme.inkSecondary)
                                } else {
                                    Text("\(event.start.formatted("h:mm a")) – \(event.end.formatted("h:mm a")) · \(event.durationLabel)")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Theme.inkSecondary)
                                }
                            }
                        }
                    }

                    // Share
                    shareButton

                    // Join call
                    if let url = meetingURL {
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            UIApplication.shared.open(url)
                        } label: {
                            Label("Join Video Call", systemImage: "video.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Theme.sunset)
                                .clipShape(.rect(cornerRadius: 14))
                                .shadow(color: Theme.accent.opacity(0.3), radius: 10, x: 0, y: 6)
                        }
                        .buttonStyle(.plain)
                    }

                    // Location
                    if let location = event.location, !location.isEmpty {
                        detailRow(icon: "mappin.and.ellipse", label: "Location") {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(location)
                                    .font(.system(size: 15))
                                    .foregroundStyle(Theme.ink)
                                if !MeetingLinkDetector.isLikelyURL(location) {
                                    Button {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        openDirections(to: location)
                                    } label: {
                                        Label("Get Directions", systemImage: "arrow.triangle.turn.up.right.circle.fill")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(Theme.accent)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(Theme.accentSoft.opacity(0.6))
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    // Travel time / Leave by
                    if let location = routableLocation {
                        if premiumStore.isPremium {
                            TravelLeaveByCard(
                                location: location,
                                eventStart: event.start,
                                origin: userLocation
                            )
                        } else {
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                showPaywall = true
                            } label: {
                                travelUpsellCard
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Notes
                    if let notes = event.notes, !notes.isEmpty {
                        detailRow(icon: "note.text", label: "Notes") {
                            Text(notes)
                                .font(.system(size: 15))
                                .foregroundStyle(Theme.inkSecondary)
                        }
                    }

                    // Delete
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete Event", systemImage: "trash")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(.red.opacity(0.1))
                            .clipShape(.rect(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                }
                .padding(20)
            }
            .background(Theme.background)
            .navigationTitle("Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { onDismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.accent)
                }
            }
            .alert("Delete Event", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    store.delete(event)
                    onDismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete \"\(event.title)\"? This cannot be undone.")
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(store: premiumStore)
            }
            .onAppear(perform: renderShareCard)
        }
    }

    // MARK: - Share

    @ViewBuilder
    private var shareButton: some View {
        if premiumStore.isPremium, let shareImage {
            ShareLink(
                item: shareImage,
                preview: SharePreview(event.title, image: shareImage)
            ) {
                shareLabel(title: "Share Event", systemImage: "square.and.arrow.up")
            }
            .simultaneousGesture(TapGesture().onEnded {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            })
        } else if !premiumStore.isPremium {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showPaywall = true
            } label: {
                shareLabel(title: "Share as Card", systemImage: "crown.fill")
            }
            .buttonStyle(.plain)
        }
    }

    private var travelUpsellCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "car.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 38, height: 38)
                .background(Theme.accentSoft.opacity(0.6))
                .clipShape(.rect(cornerRadius: 11))
            VStack(alignment: .leading, spacing: 2) {
                Text("Travel time & Leave-by alerts")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text("Know exactly when to head out. Premium.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.inkSecondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "crown.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.accent)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.hairline, lineWidth: 1))
    }

    private func shareLabel(title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Theme.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Theme.accentSoft.opacity(0.6))
            .clipShape(.rect(cornerRadius: 14))
    }

    /// Renders the share card to an image once the view appears.
    @MainActor
    private func renderShareCard() {
        let renderer = ImageRenderer(content: EventShareCard(event: event))
        renderer.scale = 3
        if let uiImage = renderer.uiImage {
            shareImage = Image(uiImage: uiImage)
        }
    }

    /// Opens Apple Maps with a directions query for the event's location string.
    private func openDirections(to location: String) {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = location
        MKLocalSearch(request: request).start { response, _ in
            if let mapItem = response?.mapItems.first {
                mapItem.openInMaps(launchOptions: [
                    MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
                ])
            } else {
                let encoded = location.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? location
                if let url = URL(string: "http://maps.apple.com/?daddr=\(encoded)") {
                    UIApplication.shared.open(url)
                }
            }
        }
    }

    private func detailRow<Content: View>(icon: String, label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.inkTertiary)
                Text(label.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.inkTertiary)
            }
            content()
                .padding(.leading, 22)
        }
    }
}

// MARK: - Travel "Leave by" Card

/// Computes and presents a driving travel-time estimate plus the latest "leave by" time
/// for an upcoming event with a physical location.
private struct TravelLeaveByCard: View {
    let location: String
    let eventStart: Date
    let origin: CLLocation?

    @State private var estimator = TravelTimeEstimator()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "car.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.accent)
                Text("GETTING THERE")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.inkTertiary)
                Spacer()
            }

            if estimator.isLoading {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Estimating travel time…")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.inkSecondary)
                }
            } else if let estimate = estimator.estimate {
                let leaveBy = estimate.leaveBy(eventStart: eventStart)
                let leaveNow = leaveBy <= Date()
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(estimate.durationLabel)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(Theme.ink)
                        Text("drive")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.inkTertiary)
                    }
                    Rectangle()
                        .fill(Theme.hairline)
                        .frame(width: 1, height: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(leaveNow ? "Leave now" : "Leave by \(leaveBy.timeLabel)")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(leaveNow ? Theme.accent : Theme.ink)
                        Text("to arrive on time")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.inkTertiary)
                    }
                    Spacer(minLength: 0)
                }
            } else if estimator.failed {
                Text(origin == nil
                     ? "Enable location access to see travel time."
                     : "Couldn't estimate travel time for this location.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.inkSecondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.hairline, lineWidth: 1))
        .task {
            await estimator.estimate(to: location, from: origin)
        }
    }
}
