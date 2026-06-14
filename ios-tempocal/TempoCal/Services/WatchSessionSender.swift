//
//  WatchSessionSender.swift
//  TempoCal
//
//  Pushes premium entitlement state to the paired Apple Watch so the
//  watch complication can gate its content behind ChronoSync Premium.
//

import Foundation
import WatchConnectivity
import EventKit

final class WatchSessionSender: NSObject, WCSessionDelegate {
    private var pendingPremium: Bool?

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    /// Mirrors the premium flag to the watch. Safe to call before the session is active.
    func update(isPremium: Bool) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else {
            pendingPremium = isPremium
            return
        }
        send(isPremium, on: session)
    }

    private func send(_ isPremium: Bool, on session: WCSession) {
        let payload: [String: Any] = ["isPremium": isPremium]
        try? session.updateApplicationContext(payload)
        // Also queue a guaranteed-delivery transfer in case the context is identical.
        session.transferUserInfo(payload)
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        guard activationState == .activated else { return }
        Task { @MainActor in
            if let pending = self.pendingPremium {
                self.send(pending, on: session)
                self.pendingPremium = nil
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        guard let phrase = userInfo["createEventPhrase"] as? String else { return }
        Task { @MainActor in
            self.createEvent(from: phrase)
        }
    }

    /// Creates a real calendar event from a phrase dictated on the watch.
    private func createEvent(from phrase: String) {
        let store = EKEventStore()
        let status = EKEventStore.authorizationStatus(for: .event)
        guard status == .fullAccess || status == .writeOnly else { return }
        let parsed = NaturalLanguageEventParser.parse(phrase)
        guard !parsed.isReminder else { return }
        let event = EKEvent(eventStore: store)
        event.title = parsed.title
        event.startDate = parsed.start
        event.endDate = parsed.end
        event.isAllDay = parsed.isAllDay
        if let location = parsed.location { event.location = location }
        event.calendar = store.defaultCalendarForNewEvents
        try? store.save(event, span: .thisEvent)
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
}
