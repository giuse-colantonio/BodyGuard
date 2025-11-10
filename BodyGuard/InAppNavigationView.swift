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
    
    // MARK: - Route Calculation
    /// Calculates a route from the user's location to the selected destination.
    func calculateRoute(from userCoordinate: CLLocationCoordinate2D,
                        to destination: MKMapItem,
                        transport: MKDirectionsTransportType = .automobile) {
        isCalculating = true
        lastError = nil
        
        let sourceItem: MKMapItem
        
        // New initializer for iOS 26
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
        
        let directions = MKDirections(request: request)
        
        Task { @MainActor in
            defer { self.isCalculating = false }
            do {
                let response = try await directions.calculate()
                guard let route = response.routes.first else {
                    self.lastError = NSError(domain: "RouteManager",
                                             code: 404,
                                             userInfo: [NSLocalizedDescriptionKey: "No route found."])
                    self.route = nil
                    self.steps.removeAll()
                    self.distanceRemaining = nil
                    self.etaRemaining = nil
                    return
                }
                
                self.route = route
                self.steps = route.steps.filter { !$0.instructions.isEmpty }
                
                // Impostazione iniziale come Apple Maps
                self.distanceRemaining = route.distance
                self.etaRemaining = route.expectedTravelTime
                
                print("Route calculated with \(self.steps.count) navigation steps.")
            } catch {
                self.lastError = error
                self.route = nil
                self.steps.removeAll()
                self.distanceRemaining = nil
                self.etaRemaining = nil
                print("Route calculation failed: \(error.localizedDescription)")
            }
        }
    }
      
    // MARK: - Live Updates
    /// Aggiorna distanza residua ed ETA basandosi sulla posizione corrente dell’utente.
    /// Richiamalo dal tuo LocationManager quando ricevi nuovi aggiornamenti di posizione.
    func updateDistanceAndETA(from userCoordinate: CLLocationCoordinate2D) {
        guard let route = route else {
            distanceRemaining = nil
            etaRemaining = nil
            return
        }
        
        // Distanza proiettata sul polyline fino alla fine del percorso
        let remaining = remainingDistance(from: userCoordinate, along: route.polyline)
        distanceRemaining = remaining
        
        // Stima ETA: se abbiamo expectedTravelTime e distanza totale, stimiamo velocità media della route
        if route.distance > 0 && route.expectedTravelTime > 0 {
            let averageSpeed = route.distance / route.expectedTravelTime // m/s
            etaRemaining = averageSpeed > 0 ? remaining / averageSpeed : nil
        } else {
            etaRemaining = nil
        }
    }
    
    /// Calcola la distanza rimanente proiettando la posizione utente sulla polyline e sommando la lunghezza residua.
    private func remainingDistance(from user: CLLocationCoordinate2D, along polyline: MKPolyline) -> CLLocationDistance {
        // Trova il punto della polyline più vicino alla posizione dell’utente
        let userMapPoint = MKMapPoint(user)
        let nearest = nearestPoint(on: polyline, to: userMapPoint)
        
        // Distanza residua: dalla proiezione fino alla fine della polyline
        let total = polyline.length()
        let traveled = distanceAlongPolyline(to: nearest.index, fraction: nearest.fraction, in: polyline)
        let remaining = max(0, total - traveled)
        return remaining
    }
    
    /// Ritorna l’indice del segmento più vicino e la frazione interna al segmento [0,1] del punto proiettato.
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
    
    /// Lunghezza dalla testa della polyline fino al punto frazionario dentro al segmento dato.
    private func distanceAlongPolyline(to segmentIndex: Int, fraction: Double, in polyline: MKPolyline) -> CLLocationDistance {
        let points = polyline.points()
        let count = polyline.pointCount
        guard count > 1 else { return 0 }
        
        var sum: CLLocationDistance = 0
        // Somma segmenti completi prima di segmentIndex
        if segmentIndex > 0 {
            for i in 0..<(segmentIndex) {
                sum += points[i].distance(to: points[i + 1])
            }
        }
        // Aggiungi la porzione del segmento corrente
        let a = points[segmentIndex]
        let b = points[min(segmentIndex + 1, count - 1)]
        let segLen = a.distance(to: b)
        sum += segLen * fraction
        return sum
    }
    
    // MARK: - Reset
    /// Clears the current route and steps.
    func clearRoute() {
        route = nil
        steps.removeAll()
        lastError = nil
        distanceRemaining = nil
        etaRemaining = nil
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
