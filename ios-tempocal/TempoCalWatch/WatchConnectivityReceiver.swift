//
//  WatchConnectivityReceiver.swift
//  TempoCalWatch
//

import Foundation
import WatchConnectivity

/// Receives premium entitlement updates pushed from the paired iPhone.
final class WatchConnectivityReceiver: NSObject, WCSessionDelegate {
    /// Called on the main actor whenever the premium flag changes.
    var onPremiumChange: ((Bool) -> Void)?

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    /// Sends a dictated phrase to the paired iPhone so it can create the real calendar event.
    func sendCreateRequest(_ phrase: String) {
        guard WCSession.isSupported() else { return }
        WCSession.default.transferUserInfo(["createEventPhrase": phrase])
    }

    private func handle(_ context: [String: Any]) {
        guard let active = context["isPremium"] as? Bool else { return }
        Task { @MainActor in
            self.onPremiumChange?(active)
        }
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        let context = session.receivedApplicationContext
        if !context.isEmpty { handle(context) }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        handle(applicationContext)
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        handle(userInfo)
    }
}
