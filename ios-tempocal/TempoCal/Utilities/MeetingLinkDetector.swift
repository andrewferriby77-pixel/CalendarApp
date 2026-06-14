//
//  MeetingLinkDetector.swift
//  ChronoSync
//

import Foundation

/// Detects video-conferencing links (Zoom, Meet, Teams, Webex, etc.) inside event text
/// so ChronoSync can surface a one-tap "Join Video Call" button.
enum MeetingLinkDetector {
    private static let meetingHosts: [String] = [
        "zoom.us", "meet.google.com", "teams.microsoft.com", "teams.live.com",
        "webex.com", "whereby.com", "meet.jit.si", "gotomeeting.com",
        "bluejeans.com", "around.co", "discord.gg"
    ]

    /// Returns the first video-meeting URL found across the supplied text fields.
    static func firstMeetingURL(in fields: [String?]) -> URL? {
        for field in fields {
            guard let text = field, !text.isEmpty else { continue }
            if let url = meetingURL(in: text) { return url }
        }
        return nil
    }

    private static func meetingURL(in text: String) -> URL? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = detector.matches(in: text, options: [], range: range)
        for match in matches {
            guard let url = match.url, let host = url.host?.lowercased() else { continue }
            if meetingHosts.contains(where: { host == $0 || host.hasSuffix(".\($0)") }) {
                return url
            }
        }
        return nil
    }

    /// Whether the string looks like a bare URL (used to hide directions for online locations).
    static func isLikelyURL(_ text: String) -> Bool {
        let lower = text.lowercased()
        return lower.hasPrefix("http://") || lower.hasPrefix("https://") || lower.contains("zoom.us") || lower.contains("meet.google")
    }
}
