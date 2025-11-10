//
//  SearchIntegratedMapView.swift
//  BodyGuard
//
//  Created by AFP Student 33 on 09/11/25.
//

import SwiftUI
import MapKit
import CoreLocation
import Combine
import Contacts

struct SearchIntegratedMapView: View {
    // Driven by the TabView’s .searchable text
    @Binding var searchText: String

    // Reuse your existing LocationManager (declared in ContentView.swift)
    @StateObject private var locationManager = LocationManager()
    @State private var cameraPosition: MapCameraPosition = .automatic

    // Search and routing state
    @State private var suggestions: [MKMapItem] = []
    @State private var selectedDestination: MKMapItem?
    @State private var debounceCancellable: AnyCancellable?

    // Transport selection (uses your TransportUI.swift enum)
    @State private var selectedTransportUI: TransportUI = .automobile

    // Debounce configuration for search
    private let searchDebounce: TimeInterval = 0.25

    @EnvironmentObject private var routeManager: RouteManager

    var body: some View {
        ZStack(alignment: .bottom) {
            // Main map
            Map(position: $cameraPosition) {
                if let route = routeManager.route {
                    MapPolyline(route.polyline)
                        .stroke(.blue, lineWidth: 6)
                }
                if let destination = selectedDestination {
                    let coordinate: CLLocationCoordinate2D = {
                        if #available(iOS 26.0, *) {
                            destination.location.coordinate
                        } else {
                            destination.placemark.location?.coordinate ?? destination.placemark.coordinate
                        }
                    }()
                    Marker(destination.name ?? "Destination", coordinate: coordinate)
                }
                UserAnnotation()
            }
            .onAppear {
                cameraPosition = .region(locationManager.region)
            }
            .onReceive(locationManager.$region) { newRegion in
                // Keep camera roughly following the user unless a route zoom is active
                if selectedDestination == nil {
                    cameraPosition = .region(newRegion)
                }
            }
            .ignoresSafeArea()

            VStack(spacing: 10) {
                // Suggestions list (driven by the TabView search field)
                if !suggestions.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(suggestions, id: \.self) { item in
                            Button {
                                selectSuggestionAndCenter(item)
                            } label: {
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: "mappin.circle.fill")
                                        .foregroundColor(.blue)
                                        .font(.title3)
                                        .padding(.top, 2)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name ?? "Unknown")
                                            .font(.body)
                                            .foregroundColor(.primary)
                                            .lineLimit(1)

                                        Text(suggestedAddress(for: item))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                                .padding(.horizontal)
                                .padding(.vertical, 10)
                            }
                            .buttonStyle(.plain)

                            Divider()
                                .padding(.leading, 52)
                        }
                    }
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                    .padding(.horizontal)
                }

                // Transport control + start button (visible after a destination and route exist)
                if selectedDestination != nil && routeManager.route != nil {
                    transportControl

                    Button {
                        // Zoom to the full route
                        if let route = routeManager.route {
                            let rect = route.polyline.boundingMapRect
                            cameraPosition = .rect(rect)
                        }
                    } label: {
                        Text("Start route")
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal)
                    }
                }
            }
            .padding(.bottom, 8)
        }
        // React to the TabView’s search text changes (no internal TextField here)
        .onChange(of: searchText) { _, newValue in
            performSearchDebounced(newValue)
        }
        // If you want an initial search on appear when searchText is not empty
        .task(id: searchText) {
            // Optional immediate search; debounced search already handles typing
            // Uncomment to trigger immediately:
            // if !searchText.isEmpty { searchNearbyPlaces(query: searchText) }
        }
    }
}

// MARK: - Helpers
private extension SearchIntegratedMapView {
    func suggestedAddress(for item: MKMapItem) -> String {
        if #available(iOS 26.0, *) {
            // Prefer newer address representations if available
            if let reps = (item as AnyObject).value(forKey: "addressRepresentations") as? [String],
               let best = reps.first, !best.isEmpty {
                return best
            }
            return item.name ?? ""
        } else {
            let pm = item.placemark
            if let postal = pm.postalAddress {
                let formatter = CNPostalAddressFormatter()
                formatter.style = .mailingAddress
                let formatted = formatter.string(from: postal)
                    .replacingOccurrences(of: "\n", with: ", ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !formatted.isEmpty { return formatted }
            }
            return pm.title ?? item.name ?? ""
        }
    }

    func performSearchDebounced(_ text: String) {
        debounceCancellable?.cancel()
        debounceCancellable = Just(text)
            .delay(for: .seconds(searchDebounce), scheduler: RunLoop.main)
            .sink { value in
                searchNearbyPlaces(query: value)
            }
    }

    func searchNearbyPlaces(query: String) {
        guard !query.isEmpty else {
            suggestions.removeAll()
            return
        }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = locationManager.region

        let search = MKLocalSearch(request: request)
        debounceCancellable?.cancel()
        debounceCancellable = Future<[MKMapItem], Never> { promise in
            search.start { response, _ in
                promise(.success(response?.mapItems ?? []))
            }
        }
        .sink { items in
            suggestions = items
        }
    }

    func selectSuggestionAndCenter(_ item: MKMapItem) {
        selectedDestination = item
        suggestions.removeAll()
        // Reset to default transport on new selection (similar to Apple Maps)
        if selectedTransportUI != .automobile {
            selectedTransportUI = .automobile
        }
        calculateRoute(to: item)

        let coord: CLLocationCoordinate2D = {
            if #available(iOS 26.0, *) {
                item.location.coordinate
            } else {
                item.placemark.location?.coordinate ?? item.placemark.coordinate
            }
        }()
        let region = MKCoordinateRegion(center: coord,
                                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
        cameraPosition = .region(region)
    }

    func calculateRoute(to destination: MKMapItem) {
        // Use the current center from your LocationManager as the source
        let userCoordinate = locationManager.region.center

        // Delegate to RouteManager
        routeManager.calculateRoute(
            from: userCoordinate,
            to: destination,
            transport: selectedTransportUI.mkType
        )
    }

    var transportControl: some View {
        HStack(spacing: 10) {
            ForEach(TransportUI.allCases, id: \.self) { option in
                let isSelected = selectedTransportUI == option
                Button {
                    if !isSelected {
                        selectedTransportUI = option
                        if let dest = selectedDestination {
                            calculateRoute(to: dest)
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: option.iconName)
                        Text(option.label)
                            .font(.subheadline.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(isSelected ? Color.accentColor : Color(UIColor.secondarySystemBackground))
                    .foregroundStyle(isSelected ? Color.white : Color.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(.horizontal)
    }
}

#Preview {
    // Preview with a constant binding
    SearchIntegratedMapView(searchText: .constant("Roma"))
        .environmentObject(RouteManager())
}

