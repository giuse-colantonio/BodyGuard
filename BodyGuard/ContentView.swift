import SwiftUI
import MapKit
import CoreLocation
import Combine

@MainActor
final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        region.center = location.coordinate
    }
}

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @State private var cameraPosition: MapCameraPosition = .automatic   // ✅ nuovo stato per la camera
    @State private var searchText = ""
    @State private var suggestions: [MKMapItem] = []
    @State private var selectedDestination: MKMapItem?
    @State private var route: MKRoute?
    @State private var cancellable: AnyCancellable?

    var body: some View {
        ZStack(alignment: .top) {
            // MARK: - Mappa principale aggiornata
            Map(position: $cameraPosition) {
                if let route = route {
                    MapPolyline(route.polyline)
                        .stroke(.blue, lineWidth: 6)
                }

                if let destination = selectedDestination {
                    Marker(destination.name ?? "Destinazione", coordinate: destination.placemark.coordinate)
                }

                UserAnnotation()
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
            }
            .onAppear {
                // Imposta la posizione iniziale della mappa sulla posizione dell’utente
                cameraPosition = .region(locationManager.region)
            }
            .onReceive(locationManager.$region) { newRegion in
                cameraPosition = .region(newRegion)
            }

            .ignoresSafeArea()

            // MARK: - Barra di ricerca
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "magnifyingglass")
                    TextField("Cerca un luogo...", text: $searchText)
                        .onChange(of: searchText) { newValue in
                            searchNearbyPlaces(query: newValue)
                        }
                        .textFieldStyle(.plain)
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                            suggestions.removeAll()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(12)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding()

                // Lista suggerimenti
                if !suggestions.isEmpty {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(suggestions, id: \.self) { item in
                                Button {
                                    selectDestination(item)
                                } label: {
                                    HStack {
                                        Image(systemName: "mappin.circle.fill")
                                            .foregroundColor(.blue)
                                        VStack(alignment: .leading) {
                                            Text(item.name ?? "Sconosciuto")
                                                .font(.headline)
                                            Text(item.placemark.title ?? "")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                    }
                                    .padding()
                                }
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .padding(.horizontal)
                                .padding(.bottom, 4)
                            }
                        }
                    }
                    .frame(maxHeight: 250)
                }

                // Pulsante per centrare il percorso
                if selectedDestination != nil && route != nil {
                    Button(action: {
                        if let route = route {
                            let rect = route.polyline.boundingMapRect
                            let region = MKCoordinateRegion(rect)
                            cameraPosition = .region(region)
                        }
                    }) {
                        Text("Avvia percorso 🚗")
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding()
                    }
                }
            }
        }
    }

    // MARK: - Cerca luoghi vicini
    private func searchNearbyPlaces(query: String) {
        guard !query.isEmpty else {
            suggestions.removeAll()
            return
        }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = locationManager.region

        let search = MKLocalSearch(request: request)
        cancellable?.cancel()

        cancellable = Future<[MKMapItem], Never> { promise in
            search.start { response, _ in
                if let items = response?.mapItems {
                    promise(.success(items))
                } else {
                    promise(.success([]))
                }
            }
        }
        .sink { items in
            suggestions = items
        }
    }

    // MARK: - Seleziona destinazione
    private func selectDestination(_ item: MKMapItem) {
        selectedDestination = item
        suggestions.removeAll()
        calculateRoute(to: item)
    }

    // MARK: - Calcola percorso
    private func calculateRoute(to destination: MKMapItem) {
        let userCoordinate = locationManager.region.center
        let sourcePlacemark = MKPlacemark(coordinate: userCoordinate)
        let sourceItem = MKMapItem(placemark: sourcePlacemark)

        let request = MKDirections.Request()
        request.source = sourceItem
        request.destination = destination
        request.transportType = .automobile

        let directions = MKDirections(request: request)
        directions.calculate { response, _ in
            if let route = response?.routes.first {
                self.route = route
            }
        }
    }
}

#Preview {
    ContentView()
}
