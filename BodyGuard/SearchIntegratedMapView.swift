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
    @Binding var searchText: String

    @StateObject private var locationManager = LocationManager()
    @State private var cameraPosition: MapCameraPosition = .automatic

    @State private var suggestions: [MKMapItem] = []
    @State private var selectedDestination: MKMapItem?
    @State private var debounceCancellable: AnyCancellable?

    @State private var selectedTransportUI: TransportUI = .automobile
    private let searchDebounce: TimeInterval = 0.25

    @EnvironmentObject var routeManager: RouteManager

    @State private var keyboardHeight: CGFloat = 0
    @State private var showEmpathicInfo: Bool = false
    @State private var routeStarted: Bool = false // track route start

    var body: some View {
        ZStack(alignment: .bottom) {
            // Map
            Map(position: $cameraPosition) {
                if let route = routeManager.route, routeStarted {
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
                if selectedDestination == nil || !routeStarted {
                    cameraPosition = .region(newRegion)
                }
            }
            .ignoresSafeArea()

            // Top-right recommended safety button
            if selectedDestination != nil {
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            // Chiudi la tastiera prima di mostrare l'overlay
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                                          to: nil, from: nil, for: nil)
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                showEmpathicInfo.toggle()
                            }
                        } label: {
                            Label("Recommended for your safety", systemImage: "heart.text.square.fill")
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding()
                    Spacer()
                }
                .ignoresSafeArea(.keyboard) // Ignora i cambiamenti della tastiera
            }

            // Bottom controls
            VStack(spacing: 10) {
                if selectedDestination != nil {

                    // Exit button (visibile solo se la rotta è stata avviata)
                    if routeStarted {
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
                        }
                        .padding(.horizontal)
                    }

                    // Transport control (On car / On foot)
                    transportControl

                    // Start route button (solo se non si è ancora avviata la rotta)
                    if !routeStarted {
                        Button {
                            // Chiudi la tastiera
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                                          to: nil, from: nil, for: nil)
                            
                            routeStarted = true
                            if let dest = selectedDestination {
                                calculateRoute(to: dest)
                                let rect = routeManager.route?.polyline.boundingMapRect ?? MKMapRect()
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

                    // Compact navigation panel (solo se la rotta è avviata)
                    if routeStarted, routeManager.route != nil {
                        NavigationPanelView()
                            .environmentObject(routeManager)
                            .padding(.horizontal)
                    }
                }
            }
            .padding(.bottom, 8)


            // Empathic Info Overlay
            EmpathicInfoOverlay(isPresented: $showEmpathicInfo)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: 0) {
                if !suggestions.isEmpty {
                    Color.clear.frame(height: 8)
                    suggestionsContainer
                        .padding(.horizontal)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        .onChange(of: searchText) { _, newValue in
            performSearchDebounced(newValue)
        }
        .onReceive(locationManager.$region) { newRegion in
            if routeStarted {
                routeManager.updateDistanceAndETA(from: newRegion.center)
            }
        }
        .keyboardInsetReader { inset in
            keyboardHeight = inset
        }
    }
}

// MARK: - Helpers
private extension SearchIntegratedMapView {
    func exitNavigation() {
        routeManager.clearRoute()
        selectedDestination = nil
        searchText = ""
        suggestions.removeAll()
        cameraPosition = .region(locationManager.region)
        routeStarted = false

        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
    }

    var rowHeight: CGFloat { 56 }

    @ViewBuilder
    var suggestionsContainer: some View {
        let count = suggestions.count
        if count <= 2 {
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    ForEach(suggestions, id: \.self) { item in
                        suggestionRow(for: item)
                        if item != suggestions.last { Divider().padding(.leading, 52) }
                    }
                }
                .padding(.top, 6)
            }
            .frame(height: rowHeight * CGFloat(count) + 6)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        } else {
            ScrollView {
                VStack(spacing: 0) {
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
        if selectedTransportUI != .automobile { selectedTransportUI = .automobile }
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
        content.background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear { onChange(proxy.safeAreaInsets.bottom) }
                    .onChange(of: proxy.safeAreaInsets) { _, _ in
                        onChange(proxy.safeAreaInsets.bottom)
                    }
            }
        )
    }
}

private extension View {
    func keyboardInsetReader(_ onChange: @escaping (CGFloat) -> Void) -> some View {
        modifier(KeyboardInsetReader(onChange: onChange))
    }
}

// MARK: - Empathic Info Overlay
private struct EmpathicInfoOverlay: View {
    @Binding var isPresented: Bool
    var body: some View {
        if isPresented {
            ZStack {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut) { isPresented = false }
                    }

                VStack(spacing: 16) {
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.pink)

                    Text("We've chosen this route by analyzing multiple safety factors: lighting, crime risk, weather, and accident history. 💙\n\nOur goal is not just to get you there faster — but to get you there safer.")
                        .multilineTextAlignment(.center)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .padding(.horizontal)

                    Button("Got it") {
                        withAnimation(.spring) { isPresented = false }
                    }
                    .font(.headline)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.9))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                }
                .padding(30)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(radius: 20)
                .padding(40)
            }
            .transition(.opacity.combined(with: .scale))
        }
    }
}

// MARK: - Preview
#Preview {
    SearchIntegratedMapView(searchText: .constant("Roma"))
        .environmentObject(RouteManager())
}
