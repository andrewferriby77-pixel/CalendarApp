//
//  WKHaptic.swift
//  TempoCalWatch
//

import WatchKit

/// Thin wrapper around the watch's Taptic Engine for delightful confirmations.
enum WKHaptic {
    static func success() {
        WKInterfaceDevice.current().play(.success)
    }

    static func tap() {
        WKInterfaceDevice.current().play(.click)
    }
}
