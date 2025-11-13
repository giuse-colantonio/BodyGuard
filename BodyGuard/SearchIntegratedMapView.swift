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
import SwiftData
import MessageUI

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

    // Leggi i contatti salvati (useremo tutti i contatti dell’app automaticamente)
    @Query(sort: [
        SortDescriptor(\Contact.lastName),
        SortDescriptor(\Contact.firstName)
    ]) private var contacts: [Contact]

    // Messaggi (composer)
    @State private var showMessageComposer = false
    @State private var messageRecipients: [String] = []
    @State private var messageBody: String = ""
    @State private var pendingRouteDestination: MKMapItem? = nil // per avviare il routing dopo il composer

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

            // Top overlays
            if selectedDestination != nil {
                VStack(spacing: 8) {
                    if routeStarted {
                        etaPill
                            .frame(maxWidth: .infinity)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    HStack {
                        Spacer()
                        Button {
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

                    Spacer()
                }
                .padding(.top, 12)
                .padding(.horizontal)
                .ignoresSafeArea(.keyboard)
            }

            // Bottom controls
            VStack(spacing: 12) {
                if selectedDestination != nil {

                    // Exit button
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

                    // Transport control (hidden once route started)
                    if !routeStarted {
                        transportControl
                    }

                    // Mostra quanti contatti verranno inclusi
                    if !routeStarted {
                        Text(recipientsCountText())
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // Start route button
                    if !routeStarted {
                        Button {
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                                            to: nil, from: nil, for: nil)

                            // Prepara messaggio di “check-in” con TUTTI i contatti dell’app (senza filtrare cifre)
                            if let dest = selectedDestination {
                                let (recipients, body) = composeCheckInMessageForAllContacts(for: dest)
                                messageRecipients = recipients
                                messageBody = body
                                pendingRouteDestination = dest
                            } else {
                                messageRecipients = []
                                messageBody = ""
                                pendingRouteDestination = nil
                            }

                            // Log di debug per verificare destinatari su device
                            print("Message recipients: \(messageRecipients)")

                            // Apri Messaggi se possibile e se abbiamo destinatari
                            if MFMessageComposeViewController.canSendText(),
                               !messageRecipients.isEmpty {
                                showMessageComposer = true
                            } else {
                                // Fallback: avvia direttamente la route
                                routeStarted = true
                                if let dest = selectedDestination {
                                    calculateRoute(to: dest)
                                }
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
                        // Presenta Messaggi
                        .sheet(isPresented: $showMessageComposer, onDismiss: {
                            // Dopo la chiusura del composer, avvia la route se avevamo una destinazione
                            if let dest = pendingRouteDestination {
                                routeStarted = true
                                calculateRoute(to: dest)
                                pendingRouteDestination = nil
                            }
                        }) {
                            MessageComposer(recipients: messageRecipients, bodyText: messageBody) { _ in
                                // result: .sent, .cancelled, .failed — opzionale da gestire
                            }
                        }
                    }

                    // Pannello navigazione
                    if routeStarted, routeManager.route != nil {
                        NavigationPanelView()
                            .environmentObject(routeManager)
                            .padding(.horizontal)
                            .padding(.vertical, 2)
                    }
                }
            }
            .padding(.bottom, 10)

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
        .onReceive(routeManager.$route) { route in
            if let route = route, routeStarted {
                cameraPosition = .rect(route.polyline.boundingMapRect)
            }
        }
        .keyboardInsetReader { inset in
            keyboardHeight = inset
        }
    }
}

// MARK: - Helpers
private extension SearchIntegratedMapView {
    func recipientsCountText() -> String {
        // Conta quanti numeri useremo (accetta qualsiasi stringa non vuota)
        let count = contacts.filter { !$0.phoneNumber.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty }.count
        if count == 0 {
            return "Nessun contatto salvato nell’app"
        } else if count == 1 {
            return "Invierai a 1 contatto"
        } else {
            return "Invierai a \(count) contatti"
        }
    }

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
                    .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
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
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)

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

    var etaPill: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock")
                .imageScale(.medium)
            Text(etaDurationText(routeManager.etaRemaining))
                .font(.body.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    func etaDurationText(_ eta: TimeInterval?) -> String {
        guard let t = eta else { return "ETA –" }
        let minutes = Int((t / 60).rounded())
        if minutes < 60 {
            return "ETA \(minutes) min"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            if mins == 0 {
                return "ETA \(hours) h"
            } else {
                return "ETA \(hours) h \(mins) min"
            }
        }
    }

    // MARK: - Check-in message (tutti i contatti dell’app, senza filtrare cifre)
    func composeCheckInMessageForAllContacts(for destination: MKMapItem) -> ([String], String) {
        // Prendi esattamente il valore salvato, purché non sia vuoto
        let recipients = contacts
            .map { $0.phoneNumber.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        // Coordinate destinazione
        let destCoord: CLLocationCoordinate2D = {
            if #available(iOS 26.0, *) {
                destination.location.coordinate
            } else {
                destination.placemark.location?.coordinate ?? destination.placemark.coordinate
            }
        }()

        // Link Apple Maps alla destinazione
        let mapsLink = "http://maps.apple.com/?daddr=\(destCoord.latitude),\(destCoord.longitude)"

        // Posizione corrente
        let current = locationManager.region.center
        let currentStr = "\(String(format: "%.5f", current.latitude)), \(String(format: "%.5f", current.longitude))"

        let destName = destination.name ?? "destination"

        let body =
        """
        Check-in: sto iniziando un tragitto verso \(destName).
        Posizione attuale: \(currentStr)
        Link Apple Maps: \(mapsLink)
        """

        return (recipients, body)
    }
}

// MARK: - Keyboard inset reader (file-scope)
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
        self.modifier(KeyboardInsetReader(onChange: onChange))
    }
}

// MARK: - Empathic Info Overlay (file-scope)
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