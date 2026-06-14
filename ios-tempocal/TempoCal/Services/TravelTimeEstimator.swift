//
//  TravelTimeEstimator.swift
//  ChronoSync
//

import Foundation
import Observation
import MapKit
import CoreLocation

/// Result of a travel-time lookup for an event with a physical location.
nonisolated struct TravelEstimate: Equatable {
    let travelTime: TimeInterval
    let destinationName: String

    /// "12 min" style label.
    var durationLabel: String {
        let minutes = max(1, Int((travelTime / 60).rounded()))
        if minutes < 60 { return "\(minutes) min" }
        let h = minutes / 60
        let m = minutes % 60
        return m == 0 ? "\(h) hr" : "\(h) hr \(m) min"
    }

    /// The latest time to leave to arrive by `eventStart`.
    func leaveBy(eventStart: Date) -> Date {
        eventStart.addingTimeInterval(-travelTime)
    }
}

/// Computes driving travel time from the user's current location to an event's
/// physical location using MapKit. Powers the "Leave by" card on Event Detail.
@MainActor
@Observable
final class TravelTimeEstimator {
    private(set) var estimate: TravelEstimate?
    private(set) var isLoading = false
    private(set) var failed = false

    /// Geocodes `location`, then computes a driving ETA from `origin`.
    func estimate(to location: String, from origin: CLLocation?) async {
        guard let origin else {
            failed = true
            return
        }
        isLoading = true
        failed = false
        defer { isLoading = false }

        let searchRequest = MKLocalSearch.Request()
        searchRequest.naturalLanguageQuery = location
        searchRequest.region = MKCoordinateRegion(
            center: origin.coordinate,
            latitudinalMeters: 80_000,
            longitudinalMeters: 80_000
        )

        do {
            let response = try await MKLocalSearch(request: searchRequest).start()
            guard let destination = response.mapItems.first else {
                failed = true
                return
            }

            let directionsRequest = MKDirections.Request()
            directionsRequest.source = MKMapItem(placemark: MKPlacemark(coordinate: origin.coordinate))
            directionsRequest.destination = destination
            directionsRequest.transportType = .automobile

            let eta = try await MKDirections(request: directionsRequest).calculateETA()
            estimate = TravelEstimate(
                travelTime: eta.expectedTravelTime,
                destinationName: destination.name ?? location
            )
        } catch {
            failed = true
        }
    }
}
