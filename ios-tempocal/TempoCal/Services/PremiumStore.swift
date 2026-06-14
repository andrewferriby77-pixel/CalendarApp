//
//  PremiumStore.swift
//  TempoCal
//

import Foundation
import Observation
import RevenueCat

/// Central source of truth for TempoCal Premium entitlement and the offering shown on the paywall.
@Observable
@MainActor
final class PremiumStore {
    var offerings: Offerings?
    var isPremium = false {
        didSet {
            guard oldValue != isPremium else { return }
            watchSync.update(isPremium: isPremium)
        }
    }
    var isLoading = false
    var isPurchasing = false
    var error: String?

    private let watchSync = WatchSessionSender()

    init() {
        Task { await listenForUpdates() }
        Task { await fetchOfferings() }
        Task { await checkStatus() }
        // Push the last-known state to the watch on launch.
        watchSync.update(isPremium: isPremium)
    }

    private func listenForUpdates() async {
        for await info in Purchases.shared.customerInfoStream {
            self.isPremium = info.entitlements["premium"]?.isActive == true
        }
    }

    func fetchOfferings() async {
        isLoading = true
        do {
            offerings = try await Purchases.shared.offerings()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func purchase(package: Package) async {
        isPurchasing = true
        do {
            let result = try await Purchases.shared.purchase(package: package)
            if !result.userCancelled {
                isPremium = result.customerInfo.entitlements["premium"]?.isActive == true
            }
        } catch ErrorCode.purchaseCancelledError {
            // StoreKit cancellation — not an error
        } catch ErrorCode.paymentPendingError {
            // Awaiting parental approval or extra auth — not a failure
        } catch {
            self.error = error.localizedDescription
        }
        isPurchasing = false
    }

    func restore() async {
        do {
            let info = try await Purchases.shared.restorePurchases()
            isPremium = info.entitlements["premium"]?.isActive == true
        } catch {
            self.error = error.localizedDescription
        }
    }

    func checkStatus() async {
        do {
            let info = try await Purchases.shared.customerInfo()
            isPremium = info.entitlements["premium"]?.isActive == true
        } catch {
            self.error = error.localizedDescription
        }
    }
}
