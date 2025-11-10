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

@MainActor
final class RouteManager: ObservableObject {
    // MARK: - Published Properties
    @Published var route: MKRoute?
    @Published var steps: [MKRoute.Step] = []
    @Published var isCalculating = false
    @Published var lastError: Error?
    
    
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
                    return
                }
                
                self.route = route
                self.steps = route.steps.filter { !$0.instructions.isEmpty }
                print("Route calculated with \(self.steps.count) navigation steps.")
            } catch {
                self.lastError = error
                self.route = nil
                self.steps.removeAll()
                print("Route calculation failed: \(error.localizedDescription)")
            }
        }
    }
      
    // MARK: - Reset
    /// Clears the current route and steps.
    func clearRoute() {
        route = nil
        steps.removeAll()
        lastError = nil
    }
}
