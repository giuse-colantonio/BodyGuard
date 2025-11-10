import SwiftUI
import MapKit
import CoreLocation
import Combine
import Contacts

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
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        Task { @MainActor in
            region.center = location.coordinate
        }
    }
}

struct ContentView: View {
    
    @StateObject private var locationManager = LocationManager()
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var searchText = ""
    @State private var suggestions: [MKMapItem] = []
    @State private var selectedDestination: MKMapItem?
    @State private var route: MKRoute?
    @State private var cancellable: AnyCancellable?
    @State var showInternalSearch = false

    
    // Use the UI enum instead of MKDirectionsTransportType
    @State private var selectedTransportUI: TransportUI = .automobile
    
    // Apple Maps–like search behavior
    @FocusState private var searchFocused: Bool
    private let searchDebounce: TimeInterval = 0.25
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // MARK: - Mappa principale aggiornata
            Map(position: $cameraPosition) {
                if let route = route {
                    MapPolyline(route.polyline)
                        .stroke(.blue, lineWidth: 6)
                }
                if let destination = selectedDestination {
                    let coordinate: CLLocationCoordinate2D = {
                        if #available(iOS 26.0, *) {
                            // In iOS 26, MKMapItem.location is NON-optional
                            return destination.location.coordinate
                        } else {
                            // Fallback for older iOS versions
                            if let location = destination.placemark.location {
                                return location.coordinate
                            } else {
                                return destination.placemark.coordinate
                            }
                        }
                    }()
                    
                    Marker(destination.name ?? "Destinazione", coordinate: coordinate)
                }
                
                UserAnnotation()
            }
            .onAppear {
                // Imposta la posizione iniziale della mappa sulla posizione dell’utente
                cameraPosition = .region(locationManager.region)
            }
            .onReceive(locationManager.$region) { newRegion in
                cameraPosition = .region(newRegion)
            }
            .ignoresSafeArea()
            
        }
    }
    
    }

#Preview {
    ContentView()
}
