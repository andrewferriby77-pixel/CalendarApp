//
//  PaywallView.swift
//  TempoCal
//

import SwiftUI
import RevenueCat

struct PaywallView: View {
    var store: PremiumStore
    @Environment(\.dismiss) private var dismiss

    private let perks: [(icon: String, title: String, subtitle: String)] = [
        ("sparkles", "Daily Brief", "A morning summary with your next-event countdown and open slots to fill."),
        ("car.fill", "Travel time & Leave-by alerts", "See the drive time to any event and exactly when to head out."),
        ("moon.stars.fill", "Evening Digest", "A nightly notification previewing tomorrow's schedule."),
        ("square.and.arrow.up", "Share beautiful event cards", "Send any event as a polished image card to anyone, anywhere."),
        ("rectangle.3.group.fill", "Calendar Sets", "Toggle Work, Personal, Health and Travel groups in a tap."),
        ("apple.logo", "Watch, Widgets & Vision Pro", "The full ChronoSync experience across every Apple device.")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    hero
                    perksList
                    purchaseSection
                    legal
                }
                .padding(.horizontal, 22)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
            .background(Theme.background.ignoresSafeArea())
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
                ToolbarItem(placement: .primaryAction) {
                    Button("Restore") {
                        Task { await store.restore() }
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                }
            }
            .alert("Something went wrong", isPresented: .init(
                get: { store.error != nil },
                set: { if !$0 { store.error = nil } }
            )) {
                Button("OK") { store.error = nil }
            } message: {
                Text(store.error ?? "")
            }
            .onChange(of: store.isPremium) { _, isPremium in
                if isPremium { dismiss() }
            }
        }
    }

    private var hero: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Theme.sunset)
                    .frame(width: 88, height: 88)
                    .shadow(color: Theme.accent.opacity(0.4), radius: 18, x: 0, y: 10)
                Image(systemName: "crown.fill")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(.white)
            }
            .padding(.top, 8)

            Text("ChronoSync Premium")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(Theme.ink)
            Text("One payment. Yours forever.")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.inkSecondary)
        }
    }

    private var perksList: some View {
        VStack(spacing: 14) {
            ForEach(perks, id: \.title) { perk in
                HStack(spacing: 14) {
                    Image(systemName: perk.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 44, height: 44)
                        .background(Theme.accentSoft.opacity(0.6))
                        .clipShape(.rect(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(perk.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                        Text(perk.subtitle)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(Theme.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(18)
        .background(Theme.surface)
        .clipShape(.rect(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.hairline, lineWidth: 1))
    }

    @ViewBuilder
    private var purchaseSection: some View {
        if store.isLoading {
            ProgressView()
                .padding(.vertical, 20)
        } else if let current = store.offerings?.current,
                  !current.availablePackages.isEmpty {
            VStack(spacing: 12) {
                ForEach(current.availablePackages, id: \.identifier) { package in
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        Task { await store.purchase(package: package) }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(package.storeProduct.localizedTitle)
                                    .font(.system(size: 17, weight: .bold))
                                Text("Unlock everything, forever")
                                    .font(.system(size: 13, weight: .medium))
                                    .opacity(0.85)
                            }
                            Spacer()
                            Text(package.storeProduct.localizedPriceString)
                                .font(.system(size: 20, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 18)
                        .frame(maxWidth: .infinity)
                        .background(Theme.sunset)
                        .clipShape(.rect(cornerRadius: 16))
                        .shadow(color: Theme.accent.opacity(0.35), radius: 14, x: 0, y: 8)
                    }
                    .buttonStyle(.plain)
                    .disabled(store.isPurchasing)
                    .opacity(store.isPurchasing ? 0.6 : 1)
                }

                if store.isPurchasing {
                    ProgressView()
                        .padding(.top, 4)
                }
            }
        } else {
            ContentUnavailableView("Unable to Load", systemImage: "exclamationmark.triangle")
                .padding(.vertical, 20)
        }
    }

    private var legal: some View {
        VStack(spacing: 12) {
            Text("A one-time purchase that unlocks all premium features on this Apple ID. No subscription, no renewals.")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Theme.inkTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)

            HStack(spacing: 6) {
                Link("Terms of Use", destination: URL(string: "https://puffincruisesamble.co.uk/terms")!)
                Text("•")
                    .foregroundStyle(Theme.inkTertiary)
                Link("Privacy Policy", destination: URL(string: "https://puffincruisesamble.co.uk/privacy-policy/")!)
            }
            .font(.system(size: 12, weight: .semibold))
            .tint(Theme.accent)
        }
    }
}
