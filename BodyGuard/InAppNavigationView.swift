//
//  RouteManager.swift
//  YourApp
//
//  Created by ChatGPT
//  Handles route calculation, navigation steps, and voice guidance.
//

import SwiftUI
import MapKit
import Combine
import CoreLocation

@MainActor
final class RouteManager: ObservableObject {
    // MARK: - Published Properties
    @Published var route: MKRoute?
    @Published var steps: [MKRoute.Step] = []
    @Published var isCalculating = false
    @Published var lastError: Error?
    
    // Apple Maps–like metrics
    @Published var distanceRemaining: CLLocationDistance?
    @Published var etaRemaining: TimeInterval?

    // Safety configuration
    var safetyWeights = SafetyWeights()
    var safetyProvider: SafetyDataProvider = SafetyDataProviderMock()
    var samplingMeters: CLLocationDistance = 150
    //mark: clear
    
    func clearRoute() {
        route = nil
        steps.removeAll()
        distanceRemaining = nil
        etaRemaining = nil
        isCalculating = false
        lastError = nil
    }

    // MARK: - Route Calculation
    /// Calculates the safest route (not the fastest) from the user's location to the destination.
    func calculateRoute(from userCoordinate: CLLocationCoordinate2D,
                        to destination: MKMapItem,
                        transport: MKDirectionsTransportType = .automobile) {
        isCalculating = true
        lastError = nil
        
        let sourceItem: MKMapItem
        if #available(iOS 26.0, *) {
            let userLocation = CLLocation(latitude: userCoordinate.latitude,
                                          longitude: userCoordinate.longitude)
            sourceItem = MKMapItem(location: userLocation, address: nil)
        } else {
            let placemark = MKPlacemark(coordinate: userCoordinate)
            sourceItem = MKMapItem(placemark: placemark)
        }
        
        let request = MKDirections.Request()
        request.source = sourceItem
        request.destination = destination
        request.transportType = transport
        request.requestsAlternateRoutes = true   // fondamentale: vogliamo più percorsi

        let directions = MKDirections(request: request)
        
        Task { @MainActor in
            defer { self.isCalculating = false }
            do {
                let response = try await directions.calculate()
                let candidates = response.routes
                guard !candidates.isEmpty else {
                    self.publishNoRouteFound()
                    return
                }

                // Valuta la sicurezza di ogni route e scegli la migliore
                let scorer = SafetyScorer(provider: safetyProvider,
                                          weights: safetyWeights,
                                          sampleDistanceMeters: samplingMeters)

                // Calcolo punteggi in parallelo fuori dal MainActor
                let scored: [(route: MKRoute, score: Double)] = try await withThrowingTaskGroup(of: (MKRoute, Double).self) { group in
                    for r in candidates {
                        group.addTask {
                            let s = await scorer.score(for: r, transport: transport)
                            return (r, s)
                        }
                    }
                    var acc: [(MKRoute, Double)] = []
                    for try await pair in group {
                        acc.append(pair)
                    }
                    return acc
                }

                // Scegli la route con score più basso (più sicura)
                guard let best = scored.min(by: { $0.score < $1.score }) else {
                    self.publishNoRouteFound()
                    return
                }

                self.route = best.route
                self.steps = best.route.steps.filter { !$0.instructions.isEmpty }
                self.distanceRemaining = best.route.distance
                self.etaRemaining = best.route.expectedTravelTime

                print("Selected safest route with score \(best.score). Candidates: \(scored.map { $0.score })")
            } catch {
                self.publishError(error)
            }
        }
    }

    // MARK: - Live Updates
    func updateDistanceAndETA(from userCoordinate: CLLocationCoordinate2D) {
        guard let route = route else {
            distanceRemaining = nil
            etaRemaining = nil
            return
        }
        let remaining = remainingDistance(from: userCoordinate, along: route.polyline)
        distanceRemaining = remaining
        if route.distance > 0 && route.expectedTravelTime > 0 {
            let averageSpeed = route.distance / route.expectedTravelTime
            etaRemaining = averageSpeed > 0 ? remaining / averageSpeed : nil
        } else {
            etaRemaining = nil
        }
    }

    private func publishNoRouteFound() {
        self.lastError = NSError(domain: "RouteManager",
                                 code: 404,
                                 userInfo: [NSLocalizedDescriptionKey: "No route found."])
        self.route = nil
        self.steps.removeAll()
        self.distanceRemaining = nil
        self.etaRemaining = nil
    }

    private func publishError(_ error: Error) {
        self.lastError = error
        self.route = nil
        self.steps.removeAll()
        self.distanceRemaining = nil
        self.etaRemaining = nil
        print("Route calculation failed: \(error.localizedDescription)")
    }
      
    // MARK: - Geometry helpers (unchanged)
    private func remainingDistance(from user: CLLocationCoordinate2D, along polyline: MKPolyline) -> CLLocationDistance {
        let userMapPoint = MKMapPoint(user)
        let nearest = nearestPoint(on: polyline, to: userMapPoint)
        let total = polyline.length()
        let traveled = distanceAlongPolyline(to: nearest.index, fraction: nearest.fraction, in: polyline)
        let remaining = max(0, total - traveled)
        return remaining
    }
    
    private func nearestPoint(on polyline: MKPolyline, to point: MKMapPoint) -> (index: Int, fraction: Double) {
        let points = polyline.points()
        let count = polyline.pointCount
        var bestIndex = 0
        var bestFraction = 0.0
        var bestDistance = CLLocationDistance.greatestFiniteMagnitude
        
        guard count > 1 else { return (0, 0) }
        
        for i in 0..<(count - 1) {
            let a = points[i]
            let b = points[i + 1]
            let ab = CGPoint(x: b.x - a.x, y: b.y - a.y)
            let ap = CGPoint(x: point.x - a.x, y: point.y - a.y)
            let abLen2 = ab.x * ab.x + ab.y * ab.y
            let t = abLen2 > 0 ? max(0, min(1, (ap.x * ab.x + ap.y * ab.y) / abLen2)) : 0
            let proj = MKMapPoint(x: a.x + t * ab.x, y: a.y + t * ab.y)
            let d = proj.distance(to: point)
            if d < bestDistance {
                bestDistance = d
                bestIndex = i
                bestFraction = t
            }
        }
        return (bestIndex, bestFraction)
    }
    
    private func distanceAlongPolyline(to segmentIndex: Int, fraction: Double, in polyline: MKPolyline) -> CLLocationDistance {
        let points = polyline.points()
        let count = polyline.pointCount
        guard count > 1 else { return 0 }
        
        var sum: CLLocationDistance = 0
        if segmentIndex > 0 {
            for i in 0..<(segmentIndex) {
                sum += points[i].distance(to: points[i + 1])
            }
        }
        let a = points[segmentIndex]
        let b = points[min(segmentIndex + 1, count - 1)]
        let segLen = a.distance(to: b)
        sum += segLen * fraction
        return sum
    }
}

// MARK: - MKPolyline helpers
private extension MKPolyline {
    func length() -> CLLocationDistance {
        let pts = points()
        guard pointCount > 1 else { return 0 }
        var total: CLLocationDistance = 0
        for i in 0..<(pointCount - 1) {
            total += pts[i].distance(to: pts[i + 1])
        }
        return total
    }
}
