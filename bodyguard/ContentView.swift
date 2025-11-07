//
//  ContentView.swift
//
//
//  Created by Salvatore Arpaia on 07/11/25.
//

import SwiftUI
import MapKit
import Contacts
import ContactsUI
import AVFoundation

// MARK: - 1. Vista Principale (Contenitore)

struct ContentView: View {
    
    @State private var selectedTab: Tab = .map
    @State private var isSearchingMap = false
    @State private var isAddingContact = false
    @State private var isFakeCallActive = false
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                VStack {
                    if selectedTab == .map {
                        MapView(isSearching: $isSearchingMap)
                    } else {
                        ContactsView(isAddingContact: $isAddingContact, showSettings: $showSettings)
                    }
                }
                .ignoresSafeArea(.container, edges: isSearchingMap ? .all : .bottom)
                
                if !isSearchingMap && !isAddingContact {
                    CustomTabBar(
                        selectedTab: $selectedTab,
                        onFakeCall: { isFakeCallActive = true },
                        onSearch: { isSearchingMap = true }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .fullScreenCover(isPresented: $isFakeCallActive) {
            FakeCallView()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }
}

enum Tab {
    case map
    case contacts
}

// MARK: - 2. La Tab Bar "Liquid Glass"

struct CustomTabBar: View {
    
    @Binding var selectedTab: Tab
    var onFakeCall: () -> Void
    var onSearch: () -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            Button(action: onFakeCall) {
                Image(systemName: "phone.arrow.down.left.fill")
                    .font(.title2)
                    .frame(width: 60, height: 60)
            }
            .foregroundStyle(.red)
            
            Spacer()
            
            Button(action: { selectedTab = .map }) {
                Image(systemName: "map.fill")
                    .font(.title2)
                    .frame(width: 60, height: 60)
            }
            .foregroundStyle(selectedTab == .map ? .blue : .gray)
            
            Spacer(minLength: 12)
            
            Button(action: { selectedTab = .contacts }) {
                Image(systemName: "person.2.fill")
                    .font(.title2)
                    .frame(width: 60, height: 60)
            }
            .foregroundStyle(selectedTab == .contacts ? .blue : .gray)
            
            Spacer()
            
            Button(action: onSearch) {
                Image(systemName: "magnifyingglass")
                    .font(.title2)
                    .frame(width: 60, height: 60)
            }
            .foregroundStyle(.gray)
        }
        .padding(.horizontal, 20)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .padding(.horizontal, 25)
        .padding(.bottom, 5)
        .animation(.spring(), value: selectedTab)
    }
}

// MARK: - 3. Location Manager (referenced here; implementation in separate file)

// NOTE: Questo tipo è richiesto dal refactor. Verrà fornito in LocationManager.swift.
// class LocationManager: NSObject, ObservableObject { ... }

// MARK: - 4. Vista Mappa con ricerca e navigazione

struct MapView: View {
    @Binding var isSearching: Bool
    @State private var searchText = ""
    
    @StateObject private var locationManager = LocationManager()
    
    @State private var position: MapCameraPosition = .automatic
    @State private var userTrackingEnabled = true
    @State private var route: MKRoute?
    @State private var routePolyline: MKPolyline?
    @State private var searchResults: [MKMapItem] = []
    @State private var selectedDestination: MKMapItem?
    
    @FocusState private var isSearchFieldFocused: Bool
    
    var body: some View {
        ZStack(alignment: .top) {
            mapLayer
                .ignoresSafeArea()
                .onChange(of: locationManager.authorizationStatus) { _, new in
                    if new == .authorizedAlways || new == .authorizedWhenInUse {
                        centerOnUser(animated: false)
                    }
                }
                .onAppear {
                    locationManager.requestWhenInUse()
                }
            
            if isSearching {
                searchOverlay
            } else {
                topControls
            }
        }
        .task(id: selectedDestination) {
            // Quando scegli una destinazione, calcola il percorso
            guard let dest = selectedDestination else { return }
            await calculateRoute(to: dest)
        }
    }
    
    private var mapLayer: some View {
        Map(position: $position, selection: .constant(nil)) {
            if let routePolyline {
                MapPolyline(routePolyline)
                    .stroke(.blue, lineWidth: 5)
            }
            if let userCoord = locationManager.lastLocation?.coordinate {
                // User annotation
                Annotation("Tu", coordinate: userCoord) {
                    ZStack {
                        Circle().fill(.blue).frame(width: 12, height: 12)
                        Circle().stroke(.white, lineWidth: 2).frame(width: 18, height: 18)
                    }
                }
            }
            ForEach(searchResults, id: \.self) { item in
                if let coord = item.placemark.location?.coordinate {
                    Marker(item.name ?? "Destinazione", coordinate: coord)
                }
            }
        }
        .mapControls {
            if userTrackingEnabled {
                MapUserLocationButton()
            }
            MapCompass()
            MapScaleView()
        }
    }
    
    private var searchOverlay: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(.ultraThinMaterial)
                .frame(height: 40)
            
            HStack(spacing: 8) {
                TextField("Dove vuoi andare?", text: $searchText)
                    .padding(10)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .focused($isSearchFieldFocused)
                
                Button("Annulla") {
                    dismissSearchUI()
                }
                .padding(.trailing)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            
            if !searchText.isEmpty {
                resultsList
            } else {
                Spacer()
            }
        }
        .onAppear {
            isSearchFieldFocused = true
        }
    }
    
    private var resultsList: some View {
        List {
            Section("Risultati") {
                ForEach(searchResults, id: \.self) { item in
                    Button {
                        selectedDestination = item
                        dismissSearchUI()
                    } label: {
                        VStack(alignment: .leading) {
                            Text(item.name ?? "Senza nome").font(.headline)
                            Text(item.placemark.title ?? "")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .task(id: searchText) {
            await performSearch(query: searchText)
        }
    }
    
    private var topControls: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Button {
                    centerOnUser(animated: true)
                } label: {
                    Image(systemName: "location.fill")
                        .padding(10)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
                if route != nil {
                    Button(role: .destructive) {
                        clearRoute()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .padding(10)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                }
            }
            .padding(.top, 12)
            .padding(.trailing, 12)
        }
    }
    
    private func dismissSearchUI() {
        isSearching = false
        isSearchFieldFocused = false
    }
    
    private func centerOnUser(animated: Bool) {
        guard let coord = locationManager.lastLocation?.coordinate else { return }
        let region = MKCoordinateRegion(center: coord, span: MKCoordinateSpan(latitudeDelta: 0.015, longitudeDelta: 0.015))
        withAnimation(animated ? .easeInOut : nil) {
            position = .region(region)
        }
    }
    
    private func clearRoute() {
        route = nil
        routePolyline = nil
        selectedDestination = nil
    }
    
    private func performSearch(query: String) async {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            return
        }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        if let coord = locationManager.lastLocation?.coordinate {
            request.region = MKCoordinateRegion(center: coord, span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2))
        }
        let search = MKLocalSearch(request: request)
        do {
            let response = try await search.start()
            await MainActor.run {
                searchResults = response.mapItems
            }
        } catch {
            print("Errore ricerca: \(error)")
            await MainActor.run { searchResults = [] }
        }
    }
    
    private func calculateRoute(to destination: MKMapItem) async {
        guard let userLocation = locationManager.lastLocation else { return }
        let source = MKMapItem(placemark: MKPlacemark(coordinate: userLocation.coordinate))
        let request = MKDirections.Request()
        request.source = source
        request.destination = destination
        request.transportType = .automobile
        
        let directions = MKDirections(request: request)
        do {
            let response = try await directions.calculate()
            guard let first = response.routes.first else { return }
            await MainActor.run {
                route = first
                routePolyline = first.polyline
                // Zoom per mostrare tutta la rotta
                let rect = first.polyline.boundingMapRect
                let region = MKCoordinateRegion(rect)
                position = .region(region)
                // Avvia monitoraggio ETA semplificato
                startMonitoring(destinationName: destination.name ?? "Destinazione", eta: first.expectedTravelTime)
            }
        } catch {
            print("Errore calcolo percorso: \(error)")
        }
    }
    
    // Monitoraggio arrivo semplificato
    private func startMonitoring(destinationName: String, eta: TimeInterval) {
        print("Monitoraggio avviato verso \(destinationName). ETA: \(Int(eta))s")
        Timer.scheduledTimer(withTimeInterval: min(eta, 120), repeats: false) { _ in
            // Esempio: se non hai logica di arrivo, invia avviso
            sendAlertToTrustedContacts(destination: destinationName)
        }
    }
    
    private func sendAlertToTrustedContacts(destination: String) {
        print("AVVISO INVIATO! L'utente non è arrivato a \(destination) in tempo.")
        // Qui integrerai SMS/Push/Server
    }
}

// MARK: - 5. Vista Contatti con gestione permessi

struct ContactsView: View {
    @Binding var isAddingContact: Bool
    @Binding var showSettings: Bool
    
    @State private var trustedContacts: [CNContact] = []
    @State private var showContactPicker = false
    @State private var contactsAccessDenied = false
    
    var body: some View {
        VStack {
            HStack {
                Text("Contatti Fidati")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Spacer()
                Button(action: { showSettings = true }) {
                    Image(systemName: "gearshape.fill")
                        .font(.title2)
                }
            }
            .padding()

            List {
                if trustedContacts.isEmpty {
                    Text("Nessun contatto fidato. Aggiungine uno con il pulsante qui sotto.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(trustedContacts, id: \.identifier) { contact in
                        Text("\(contact.givenName) \(contact.familyName)")
                    }
                    .onDelete(perform: deleteContact)
                }
            }
            
            if contactsAccessDenied {
                Text("Accesso ai contatti negato. Vai in Impostazioni per abilitarlo.")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }
            
            Button(action: {
                Task { await requestContactsAndShowPicker() }
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Aggiungi Contatto Fiduciario")
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(.blue)
                .foregroundColor(.white)
                .clipShape(Capsule())
                .padding()
            }
        }
        .sheet(isPresented: $showContactPicker, onDismiss: {
            isAddingContact = false
        }) {
            ContactPickerView(onContactSelected: { contact in
                if !trustedContacts.contains(where: { $0.identifier == contact.identifier }) {
                    trustedContacts.append(contact)
                }
            })
        }
    }
    
    func deleteContact(at offsets: IndexSet) {
        trustedContacts.remove(atOffsets: offsets)
    }
    
    private func requestContactsAndShowPicker() async {
        let store = CNContactStore()
        let status = CNContactStore.authorizationStatus(for: .contacts)
        switch status {
        case .authorized:
            isAddingContact = true
            showContactPicker = true
            contactsAccessDenied = false
        case .notDetermined:
            do {
                try await store.requestAccess(for: .contacts)
                await MainActor.run {
                    isAddingContact = true
                    showContactPicker = true
                    contactsAccessDenied = false
                }
            } catch {
                await MainActor.run { contactsAccessDenied = true }
            }
        case .denied, .restricted:
            contactsAccessDenied = true
        @unknown default:
            contactsAccessDenied = true
        }
    }
}

// MARK: - 6. Selettore Contatti (UIKit Bridge)

struct ContactPickerView: UIViewControllerRepresentable {
    
    var onContactSelected: (CNContact) -> Void
    
    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, CNContactPickerDelegate {
        var parent: ContactPickerView
        
        init(_ parent: ContactPickerView) {
            self.parent = parent
        }
        
        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            parent.onContactSelected(contact)
        }
    }
}

// MARK: - 7. Vista Finta Chiamata

struct FakeCallView: View {
    @AppStorage("fakeCallName") private var fakeCallName = "Sconosciuto"
    @Environment(\.dismiss) var dismiss
    
    @State private var audioPlayer: AVAudioPlayer?
    @State private var callStatus = "Chiamata in arrivo..."
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text(fakeCallName)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.top, 100)
                
                Text(callStatus)
                    .font(.title2)
                    .foregroundColor(.gray)
                
                Spacer()
                
                Button(action: {
                    audioPlayer?.stop()
                    dismiss()
                }) {
                    Image(systemName: "phone.down.fill")
                        .font(.largeTitle)
                        .padding(30)
                        .background(.red)
                        .foregroundColor(.white)
                        .clipShape(Circle())
                }
                .padding(.bottom, 80)
            }
        }
        .onAppear {
            playRingAndRecording()
        }
    }
    
    func playRingAndRecording() {
        callStatus = "Squillo..."
        Task {
            try? await Task.sleep(nanoseconds: 3 * 1_000_000_000)
            callStatus = "Connesso"
            guard let path = Bundle.main.path(forResource: "recording", ofType: "m4a") else {
                callStatus = "File audio non trovato"
                return
            }
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .voiceCall)
                try AVAudioSession.sharedInstance().setActive(true)
                audioPlayer = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
                audioPlayer?.play()
            } catch {
                print("Errore nel caricare la registrazione: \(error.localizedDescription)")
                callStatus = "Errore audio"
            }
        }
    }
}

// MARK: - 8. Vista Impostazioni

struct SettingsView: View {
    @AppStorage("fakeCallName") private var fakeCallName = "Sconosciuto"
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Impostazioni Finta Chiamata")) {
                    TextField("Nome chiamante", text: $fakeCallName)
                    
                    Button("Registra Audio Personalizzato") {
                        // Placeholder: implementare AVAudioRecorder se necessario
                        print("Avvio registrazione...")
                    }
                }
            }
            .navigationTitle("Impostazioni")
            .navigationBarItems(trailing: Button("Fine") {
                dismiss()
            })
        }
    }
}
