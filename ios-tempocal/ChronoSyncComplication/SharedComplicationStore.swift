//
//  SharedComplicationStore.swift
//  Shared between TempoCalWatch and ChronoSyncComplication via App Group.
//

import Foundation

/// A lightweight snapshot of the wearer's schedule shared with watch complications.
nonisolated struct ComplicationSnapshot: Codable, Equatable {
    var premiumActive: Bool
    var nextTitle: String?
    var nextStart: Date?
    var nextColor: [Double]   // [r, g, b]
    var todayCount: Int
    /// First event scheduled for tomorrow, used as a fallback once today is clear.
    var tomorrowTitle: String?
    var tomorrowStart: Date?
    var tomorrowColor: [Double]
    var tomorrowCount: Int
    var generatedAt: Date

    /// True when there are no more events left today but tomorrow has at least one.
    var showsTomorrow: Bool { nextStart == nil && tomorrowStart != nil }

    static let empty = ComplicationSnapshot(
        premiumActive: false,
        nextTitle: nil,
        nextStart: nil,
        nextColor: [1.0, 0.353, 0.302],
        todayCount: 0,
        tomorrowTitle: nil,
        tomorrowStart: nil,
        tomorrowColor: [1.0, 0.353, 0.302],
        tomorrowCount: 0,
        generatedAt: .distantPast
    )
}

/// Bridges data between the watch app and its complication extension using a shared App Group.
nonisolated enum SharedComplicationStore {
    static let appGroup = "group.app.rork.2r171bexx4vnvkub3kcrj"
    private static let key = "complicationSnapshot"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroup)
    }

    static func save(_ snapshot: ComplicationSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults?.set(data, forKey: key)
    }

    static func load() -> ComplicationSnapshot {
        guard let data = defaults?.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(ComplicationSnapshot.self, from: data) else {
            return .empty
        }
        return snapshot
    }
}
