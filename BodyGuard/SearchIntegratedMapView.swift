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

    // Keyboard safe-area height (iOS 17+). > 0 means keyboard is up.
    @State private var keyboardHeight: CGFloat = 0

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

            // Bottom overlay: exit button + transport + navigation panel
            VStack(spacing: 10) {
                // Exit navigation button (visible only while a route exists)
                if routeManager.route != nil {
                    HStack {
                        Spacer()
                        Button {
                            exitNavigation()
                        } label: {
                            Label("Exit", systemImage: "xmark.circle.fill")
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
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

                // Pannello compatto: mostra solo distanza + ETA; tap per espandere i passi
                if routeManager.route != nil {
                    NavigationPanelView()
                        .environmentObject(routeManager)
                        .padding(.horizontal)
                }
            }
            .padding(.bottom, 8)
        }
        // TOP inset: render suggestions above the search bar so they are visible and tappable.
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: 0) {
                if !suggestions.isEmpty {
                    // Add a small spacer to sit just below the search pill
                    Color.clear.frame(height: 8)

                    // The suggestions container itself
                    suggestionsContainer
                        .padding(.horizontal)
                        .transition(.move(edge: .top).combined(with: .opacity))
                } else {
                    EmptyView()
                }
            }
            .padding(.top, 0)
        }
        // React to the TabView’s search text changes (no internal TextField here)
        .onChange(of: searchText) { _, newValue in
            performSearchDebounced(newValue)
        }
        // Aggiornamento live distanza/ETA
        .onReceive(locationManager.$region) { newRegion in
            routeManager.updateDistanceAndETA(from: newRegion.center)
        }
        // Read keyboard safe-area inset to know when the keyboard is up (kept if you want to adapt further)
        .keyboardInsetReader { inset in
            keyboardHeight = inset
        }
    }
}

// MARK: - Helpers
private extension SearchIntegratedMapView {
    // Exit navigation: clear route, clear destination, clear search text, dismiss keyboard, and re-center on user
    func exitNavigation() {
        routeManager.clearRoute()
        selectedDestination = nil
        searchText = ""            // clear the TabView’s search field
        suggestions.removeAll()
        cameraPosition = .region(locationManager.region)

        // Dismiss the keyboard
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
    }

    // Approximate row height: icon + vertical paddings + text
    var rowHeight: CGFloat { 56 }

    // A container that adapts its height:
    // - 1–2 results: size to content (no ScrollView, no max cap)
    // - 3+ results: scrollable with a max height cap
    @ViewBuilder
    var suggestionsContainer: some View {
        let count = suggestions.count

        if count <= 2 {
            // Non-scrollable, height fits exactly the visible rows
            VStack(spacing: 0) {
                // Internal top padding to keep first row away from the rounded edge
                VStack(spacing: 0) {
                    ForEach(suggestions, id: \.self) { item in
                        suggestionRow(for: item)
                        if item != suggestions.last {
                            Divider().padding(.leading, 52)
                        }
                    }
                }
                .padding(.top, 6)
            }
            .frame(height: rowHeight * CGFloat(count) + 6) // account for internal top padding
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        } else {
            // Scrollable with a max height so it doesn't reach under the search field
            ScrollView {
                VStack(spacing: 0) {
                    // Internal top padding for better tap area away from the top edge
                    VStack(spacing: 0) {
                        ForEach(suggestions, id: \.self) { item in
                            suggestionRow(for: item)
                            Divider().padding(.leading, 52)
                        }
                    }
                    .padding(.top, 6)
                }
            }
            .frame(maxHeight: UIScreen.main.bounds.height * 0.35)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        }
    }

    @ViewBuilder
    func suggestionRow(for item: MKMapItem) -> some View {
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
            .frame(height: rowHeight, alignment: .center)
        }
        .buttonStyle(.plain)
    }

    func suggestedAddress(for item: MKMapItem) -> String {
        if #available(iOS 26.0, *) {
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
        let userCoordinate = locationManager.region.center
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

// MARK: - Keyboard inset reader
private struct KeyboardInsetReader: ViewModifier {
    let onChange: (CGFloat) -> Void

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { report(from: proxy) }
                        .onChange(of: proxy.safeAreaInsets) { _, _ in
                            report(from: proxy)
                        }
                }
            )
    }

    private func report(from proxy: GeometryProxy) {
        // Bottom safe area includes keyboard height when the keyboard is visible.
        onChange(proxy.safeAreaInsets.bottom)
    }
}

private extension View {
    func keyboardInsetReader(_ onChange: @escaping (CGFloat) -> Void) -> some View {
        modifier(KeyboardInsetReader(onChange: onChange))
    }
}

#Preview {
    SearchIntegratedMapView(searchText: .constant("Roma"))
        .environmentObject(RouteManager())
}
