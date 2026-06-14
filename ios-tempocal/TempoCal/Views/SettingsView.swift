//
//  SettingsView.swift
//  TempoCal
//

import SwiftUI
import UIKit
import EventKit

/// Profile / settings screen. Headlined by the Premium status card.
struct SettingsView: View {
    var premiumStore: PremiumStore
    var store: EventStore
    var reminderStore: ReminderStore
    @Bindable var notificationService: NotificationService
    @Environment(\.dismiss) private var dismiss
    @State private var showPaywall = false

    private let appVersion: String = {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    premiumCard
                    notificationsSection
                    accessSection
                    aboutSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Theme.inkSecondary)
                    }
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(store: premiumStore)
            }
        }
    }

    // MARK: - Premium

    @ViewBuilder
    private var premiumCard: some View {
        if premiumStore.isPremium {
            activePremiumCard
        } else {
            upsellPremiumCard
        }
    }

    private var activePremiumCard: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Theme.sunset)
                    .frame(width: 70, height: 70)
                    .shadow(color: Theme.accent.opacity(0.4), radius: 16, x: 0, y: 8)
                Image(systemName: "crown.fill")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.white)
            }
            VStack(spacing: 4) {
                Text("ChronoSync Premium")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Text("Unlocked forever. Thank you for your support.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.inkSecondary)
                    .multilineTextAlignment(.center)
            }
            HStack(spacing: 6) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 13, weight: .bold))
                Text("Active")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(Theme.accent)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Theme.accentSoft.opacity(0.6))
            .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 20)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.hairline, lineWidth: 1))
    }

    private var upsellPremiumCard: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            showPaywall = true
        } label: {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.2))
                            .frame(width: 48, height: 48)
                        Image(systemName: "crown.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Go Premium")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                        Text("One payment. Yours forever.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white.opacity(0.9))
                }

                VStack(alignment: .leading, spacing: 10) {
                    perkRow("sparkles", "Daily Brief & open-slot suggestions")
                    perkRow("square.and.arrow.up", "Share events as beautiful cards")
                    perkRow("apple.logo", "Watch, Widgets & Vision Pro")
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(Theme.sunset)
            .clipShape(.rect(cornerRadius: 22))
            .shadow(color: Theme.accent.opacity(0.35), radius: 16, x: 0, y: 8)
        }
        .buttonStyle(.plain)
    }

    private func perkRow(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 20)
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.95))
        }
    }

    // MARK: - Notifications

    private var notificationsSection: some View {
        SettingsCard(title: "Notifications") {
            HStack(spacing: 12) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Evening Digest")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Theme.ink)
                    Text("A nightly preview of tomorrow's schedule")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.inkTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                if premiumStore.isPremium {
                    Toggle("", isOn: digestBinding)
                        .labelsHidden()
                        .tint(Theme.accent)
                } else {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.accent)
                        .onTapGesture {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            showPaywall = true
                        }
                }
            }
            .padding(.vertical, 4)

            if premiumStore.isPremium && notificationService.isEnabled {
                Divider().background(Theme.hairline)
                HStack(spacing: 12) {
                    Image(systemName: "clock")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 28)
                    Text("Deliver at")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    DatePicker(
                        "",
                        selection: digestTimeBinding,
                        displayedComponents: [.hourAndMinute]
                    )
                    .labelsHidden()
                    .tint(Theme.accent)
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var digestBinding: Binding<Bool> {
        Binding(
            get: { notificationService.isEnabled },
            set: { newValue in
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                Task {
                    if newValue {
                        let granted = await notificationService.requestAuthorization()
                        notificationService.isEnabled = granted
                    } else {
                        notificationService.isEnabled = false
                    }
                    await notificationService.reschedule(events: store.events)
                }
            }
        )
    }

    private var digestTimeBinding: Binding<Date> {
        Binding(
            get: { notificationService.digestTime },
            set: { newValue in
                notificationService.digestTime = newValue
                Task { await notificationService.reschedule(events: store.events) }
            }
        )
    }

    // MARK: - Access

    private var accessSection: some View {
        SettingsCard(title: "Access") {
            NavigationLink {
                ConnectedAccountsView(store: store)
            } label: {
                accountsRow
            }
            .buttonStyle(.plain)
            Divider().background(Theme.hairline)
            statusRow(
                icon: "calendar",
                title: "Calendar",
                granted: store.isLive || store.authorizationStatus == .fullAccess
            )
            Divider().background(Theme.hairline)
            statusRow(
                icon: "checklist",
                title: "Reminders",
                granted: reminderStore.isAuthorized
            )
        }
    }

    private var accountsRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.2.badge.gearshape")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.accent)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text("Connected Accounts")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.ink)
                Text("iCloud, Google, Exchange, Office 365")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.inkTertiary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.inkTertiary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private func statusRow(icon: String, title: String, granted: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.accent)
                .frame(width: 28)
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.ink)
            Spacer()
            HStack(spacing: 5) {
                Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                Text(granted ? "Connected" : "Not connected")
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundStyle(granted ? Theme.accent : Theme.inkTertiary)
        }
        .padding(.vertical, 4)
    }

    // MARK: - About

    private var aboutSection: some View {
        SettingsCard(title: "About") {
            if !premiumStore.isPremium {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    Task { await premiumStore.restore() }
                } label: {
                    aboutRow(icon: "arrow.clockwise", title: "Restore Purchases", trailing: nil)
                }
                .buttonStyle(.plain)
                Divider().background(Theme.hairline)
            }
            aboutRow(icon: "info.circle", title: "Version", trailing: appVersion)
        }
    }

    private func aboutRow(icon: String, title: String, trailing: String?) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.accent)
                .frame(width: 28)
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.ink)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.inkTertiary)
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.inkTertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

/// A titled rounded container used across the settings screen.
private struct SettingsCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.inkTertiary)
                .padding(.leading, 4)
            VStack(spacing: 10) {
                content
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(Theme.surface)
            .clipShape(.rect(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.hairline, lineWidth: 1))
        }
    }
}
