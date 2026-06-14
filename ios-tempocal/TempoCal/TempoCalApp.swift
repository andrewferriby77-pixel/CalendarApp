//
//  TempoCalApp.swift
//  TempoCal
//

import SwiftUI
import AppIntents
import RevenueCat

@main
struct TempoCalApp: App {
    @State private var premiumStore: PremiumStore

    init() {
        #if DEBUG
        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: Config.EXPO_PUBLIC_REVENUECAT_TEST_API_KEY)
        #else
        Purchases.configure(withAPIKey: Config.EXPO_PUBLIC_REVENUECAT_IOS_API_KEY)
        #endif
        _premiumStore = State(initialValue: PremiumStore())
        TempoCalShortcuts.updateAppShortcutParameters()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(premiumStore: premiumStore)
        }
    }
}
