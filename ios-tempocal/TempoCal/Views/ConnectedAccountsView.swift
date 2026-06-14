//
//  ConnectedAccountsView.swift
//  TempoCal
//

import SwiftUI
import UIKit
import EventKit

/// Connected calendar accounts screen. Shows every account EventKit can see (iCloud, Google,
/// Exchange / Office 365, etc.) grouped by provider, with per-calendar visibility toggles, and a
/// guided "Add Account" flow that explains how to connect a new provider through iOS Settings.
struct ConnectedAccountsView: View {
    var store: EventStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var accounts: [CalendarAccount] = []
    @State private var showAddSheet = false

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                if store.authorizationStatus != .fullAccess && !store.isLive {
                    permissionCard
                } else if accounts.isEmpty {
                    emptyCard
                } else {
                    ForEach(accounts) { account in
                        accountCard(account)
                    }
                }

                addAccountButton
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Accounts")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: reload)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                store.reloadSources()
                reload()
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddAccountSheet()
                .presentationDetents([.large])
        }
    }

    private func reload() {
        accounts = store.connectedAccounts()
    }

    // MARK: - Account Card

    private func accountCard(_ account: CalendarAccount) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Theme.accentSoft)
                        .frame(width: 40, height: 40)
                    Image(systemName: account.provider.symbol)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(account.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text(account.provider.displayName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.inkSecondary)
                }
                Spacer()
                Text("\(account.calendars.count)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.inkTertiary)
                    + Text(account.calendars.count == 1 ? " calendar" : " calendars")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.inkTertiary)
            }
            .padding(16)

            Divider().background(Theme.hairline).padding(.horizontal, 16)

            VStack(spacing: 0) {
                ForEach(Array(account.calendars.enumerated()), id: \.element.calendarIdentifier) { index, cal in
                    calendarRow(cal)
                    if index < account.calendars.count - 1 {
                        Divider().background(Theme.hairline).padding(.leading, 50)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.hairline, lineWidth: 1))
    }

    private func calendarRow(_ cal: EKCalendar) -> some View {
        let hidden = store.isCalendarHidden(cal.calendarIdentifier)
        return Button {
            store.toggleCalendar(cal.calendarIdentifier)
            reload()
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color(cgColor: cal.cgColor))
                    .frame(width: 12, height: 12)
                Text(cal.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(hidden ? Theme.inkTertiary : Theme.ink)
                    .strikethrough(hidden, color: Theme.inkTertiary)
                Spacer()
                Image(systemName: hidden ? "eye.slash" : "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(hidden ? Theme.inkTertiary : Theme.accent)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Add Account

    private var addAccountButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            showAddSheet = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                Text("Add an account")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Theme.sunset)
            .clipShape(.rect(cornerRadius: 16))
            .shadow(color: Theme.accent.opacity(0.3), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - States

    private var permissionCard: some View {
        VStack(spacing: 14) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Theme.accent)
            Text("Calendar access needed")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Theme.ink)
            Text("Grant calendar access so ChronoSync can show the accounts you've connected on this iPhone.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.inkSecondary)
                .multilineTextAlignment(.center)
            Button {
                Task {
                    _ = await store.requestAccess()
                    reload()
                }
            } label: {
                Text("Grant Access")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Theme.accent)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.hairline, lineWidth: 1))
    }

    private var emptyCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Theme.inkTertiary)
            Text("No calendar accounts yet")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text("Add iCloud, Google, Exchange or Office 365 below and your calendars will appear here.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.inkSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.hairline, lineWidth: 1))
    }
}

/// Guided sheet explaining how to connect each provider through iOS Settings.
/// (Apps cannot add CalDAV/Exchange accounts directly — only the system Settings app can.)
private struct AddAccountSheet: View {
    @Environment(\.dismiss) private var dismiss

    private struct Provider: Identifiable {
        let id = UUID()
        let name: String
        let symbol: String
        let detail: String
    }

    private let providers: [Provider] = [
        Provider(name: "iCloud", symbol: "cloud.fill",
                 detail: "Sign in with your Apple Account, then turn on Calendars."),
        Provider(name: "Google", symbol: "g.circle.fill",
                 detail: "Add a Google account and enable Calendars to sync Gmail / Workspace."),
        Provider(name: "Microsoft Exchange", symbol: "envelope.fill",
                 detail: "Add an Exchange account with your work email and server details."),
        Provider(name: "Office 365 / Outlook", symbol: "envelope.badge.fill",
                 detail: "Choose Microsoft Exchange or Outlook.com and turn on Calendars.")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("ChronoSync reads from the calendar accounts on your iPhone. Add an account in iOS Settings and it'll instantly appear here — no extra sign-in required.")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.inkSecondary)
                        .padding(.horizontal, 4)

                    VStack(spacing: 12) {
                        ForEach(providers) { provider in
                            providerRow(provider)
                        }
                    }

                    stepsCard

                    Button(action: openSettings) {
                        HStack(spacing: 10) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 17, weight: .semibold))
                            Text("Open iOS Settings")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Theme.sunset)
                        .clipShape(.rect(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Add Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Theme.accent)
                }
            }
        }
    }

    private func providerRow(_ provider: Provider) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 11)
                    .fill(Theme.accentSoft)
                    .frame(width: 44, height: 44)
                Image(systemName: provider.symbol)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(provider.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text(provider.detail)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.inkSecondary)
            }
            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.hairline, lineWidth: 1))
    }

    private var stepsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("HOW TO ADD")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.inkTertiary)
            stepRow(1, "Open the Settings app")
            stepRow(2, "Tap Calendar, then Accounts")
            stepRow(3, "Tap Add Account and pick your provider")
            stepRow(4, "Sign in and turn on Calendars")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.hairline, lineWidth: 1))
    }

    private func stepRow(_ number: Int, _ text: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Theme.accent)
                    .frame(width: 22, height: 22)
                Text("\(number)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
            }
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.ink)
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
