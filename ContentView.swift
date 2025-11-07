//
//  ContentView.swift
//  
//
//  Created by Salvatore Arpaia on 07/11/25.
//

import SwiftUI
import MapKit // Per la mappa
import ContactsUI // Per selezionare i contatti
import AVFoundation // Per la finta chiamata

// MARK: - 1. Vista Principale (Contenitore)

struct ContentView: View {
    
    // Stato per la scheda attiva (Mappa o Contatti)
    @State private var selectedTab: Tab = .map
    
    // Stati per nascondere la Tab Bar
    @State private var isSearchingMap = false
    @State private var isAddingContact = false
    
    // Stato per mostrare la finta chiamata
    @State private var isFakeCallActive = false
    
    // Stato per mostrare le impostazioni
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                
                // --- CONTENUTO PRINCIPALE ---
                // Cambia la vista in base alla scheda selezionata
                VStack {
                    if selectedTab == .map {
                        // Passiamo il binding per la ricerca
                        MapView(isSearching: $isSearchingMap)
                    } else {
                        // Passiamo il binding per l'aggiunta di contatti
                        ContactsView(isAddingContact: $isAddingContact, showSettings: $showSettings)
                    }
                }
                .edgesIgnoringSafeArea(isSearchingMap ? .all : .bottom) // La mappa/ricerca va a schermo intero
                
                // --- TAB BAR PERSONALIZZATA ---
                // Mostra la barra solo se non stiamo cercando o aggiungendo un contatto
                if !isSearchingMap && !isAddingContact {
                    CustomTabBar(
                        selectedTab: $selectedTab,
                        onFakeCall: { isFakeCallActive = true },
                        onSearch: { isSearchingMap = true }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity)) // Animazione
                }
            }
        }
        // Modale a schermo intero per la finta chiamata
        .fullScreenCover(isPresented: $isFakeCallActive) {
            FakeCallView()
        }
        // Modale per le impostazioni
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }
}

// Enum per le schede
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
            // 1. Tasto Fake Call
            Button(action: onFakeCall) {
                Image(systemName: "phone.arrow.down.left.fill")
                    .font(.title2)
                    .frame(width: 60, height: 60)
            }
            .foregroundStyle(.red) // Colore per il tasto fake call
            
            Spacer()
            
            // 2. Tasto Mappa (Principale)
            Button(action: { selectedTab = .map }) {
                Image(systemName: "map.fill")
                    .font(.title2)
                    .frame(width: 60, height: 60)
            }
            .foregroundStyle(selectedTab == .map ? .blue : .gray)
            
            Spacer(minLength: 12)
            
            // 3. Tasto Contatti
            Button(action: { selectedTab = .contacts }) {
                Image(systemName: "person.2.fill")
                    .font(.title2)
                    .frame(width: 60, height: 60)
            }
            .foregroundStyle(selectedTab == .contacts ? .blue : .gray)
            
            Spacer()
            
            // 4. Tasto Search
            Button(action: onSearch) {
                Image(systemName: "magnifyingglass")
                    .font(.title2)
                    .frame(width: 60, height: 60)
            }
            .foregroundStyle(.gray)
        }
        .padding(.horizontal, 20)
        .background(
            // --- Effetto "Liquid Glass" ---
            .ultraThinMaterial
        )
        .clipShape(Capsule())
        .padding(.horizontal, 25)
        .padding(.bottom, 5) // Spaziatura dal fondo
        .animation(.spring(), value: selectedTab) // Animazione
    }
}

// MARK: - 3. Vista Mappa e Logica di Ricerca (CORRETTA per iOS 17+)

struct MapView: View {
    @Binding var isSearching: Bool
    @State private var searchText = ""
    
    // Usiamo `position` per iOS 17+
    @State private var position: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 40.8518, longitude: 14.2681), // Esempio: Napoli
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    ))
    
    // Per gestire la tastiera
    @FocusState private var isSearchFieldFocused: Bool

    var body: some View {
        ZStack(alignment: .top) {
            // Mappa
            Map(position: $position)
                .edgesIgnoringSafeArea(.top)
                .onTapGesture {
                    // Chiudi la tastiera se tocchi la mappa
                    isSearchFieldFocused = false
                }
            
            // --- UI di RICERCA (mostrata solo se isSearching è true) ---
            if isSearching {
                VStack(spacing: 0) {
                    // Sfondo per la barra di stato
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .frame(height: 40) // Altezza approssimativa safe area
                    
                    // Barra di ricerca
                    HStack {
                        TextField("Dove vuoi andare?", text: $searchText)
                            .padding(10)
                            .background(.regularMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .focused($isSearchFieldFocused) // Collega il focus
                            .padding(.leading)
                        
                        Button("Annulla") {
                            isSearching = false // Nasconde la UI di ricerca
                            isSearchFieldFocused = false // Nasconde la tastiera
                            searchText = ""
                        }
                        .padding(.trailing)
                    }
                    .padding(.vertical)
                    .background(.ultraThinMaterial)
                    
                    // --- Logica di Avvio ---
                    // (Questa è una simulazione)
                    if !searchText.isEmpty {
                        Button("Avvia Navigazione per: \(searchText)") {
                            // 1. Qui calcoleresti il percorso (con MKDirections)
                            // 2. Otterresti la ETA (Estimated Time of Arrival)
                            let etaInSeconds: TimeInterval = 60 // Simula 1 minuto
                            
                            // 3. Avvia la logica di monitoraggio
                            startMonitoring(destination: searchText, eta: etaInSeconds)
                            
                            // 4. Chiudi la ricerca
                            isSearching = false
                            isSearchFieldFocused = false
                        }
                        .padding()
                        .background(.blue)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                        .padding()
                        
                        Spacer()
                    } else {
                         Spacer()
                    }
                }
                .onAppear {
                    // Apri la tastiera automatically
                    isSearchFieldFocused = true
                }
            }
        }
    }
    
    // --- FUNZIONE CHIAVE: Monitoraggio Arrivo ---
    func startMonitoring(destination: String, eta: TimeInterval) {
        print("Monitoraggio avviato verso \(destination). Arrivo previsto tra \(eta) secondi.")
        
        // Simula il timer
        // In un'app reale:
        // 1. Chiederesti i permessi per la Localizzazione in Background.
        // 2. Imposteresti un timer (o un Geofence sulla destinazione).
        // 3. Se il timer scade e la posizione non è la destinazione...
        // 4. ...invia un avviso ai contatti fidati (via SMS, Push, etc.)
        
        Timer.scheduledTimer(withTimeInterval: eta, repeats: false) { _ in
            // ** LOGICA DI CONTROLLO **
            // Esempio: if !userIsAtDestination() {
                sendAlertToTrustedContacts(destination: destination)
            // }
        }
    }
    
    func sendAlertToTrustedContacts(destination: String) {
        // Qui invieresti l'avviso.
        // Esempio: "Avviso da BODYGUARD: [Tuo Nome] non è ancora arrivato/a a [Destinazione]. Potrebbe aver bisogno di aiuto."
        print("AVVISO INVIATO! L'utente non è arrivato a \(destination) in tempo.")
    }
}

// MARK: - 4. Vista Contatti e Selezione

struct ContactsView: View {
    @Binding var isAddingContact: Bool
    @Binding var showSettings: Bool
    
    // Qui salveresti i contatti scelti
    @State private var trustedContacts: [CNContact] = []
    
    // Stato per mostrare il selettore
    @State private var showContactPicker = false
    
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

            // Elenco dei contatti salvati
            List {
                ForEach(trustedContacts, id: \.identifier) { contact in
                    Text("\(contact.givenName) \(contact.familyName)")
                }
                .onDelete(perform: deleteContact)
            }
            
            Button(action: {
                isAddingContact = true // Nasconde la tab bar
                showContactPicker = true // Apre il selettore
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
        // Il selettore di contatti (richiede UIKit)
        .sheet(isPresented: $showContactPicker, onDismiss: {
            isAddingContact = false // Riemostra la tab bar quando chiuso
        }) {
            ContactPickerView(onContactSelected: { contact in
                // Aggiungi il contatto alla lista
                if !trustedContacts.contains(where: { $0.identifier == contact.identifier }) {
                    trustedContacts.append(contact)
                }
            })
        }
    }
    
    func deleteContact(at offsets: IndexSet) {
        trustedContacts.remove(atOffsets: offsets)
    }
}

// MARK: - 5. Selettore Contatti (UIKit Bridge)

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
        
        // Chiamato quando un contatto viene selezionato
        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            parent.onContactSelected(contact)
        }
    }
}


// MARK: - 6. Vista Finta Chiamata

struct FakeCallView: View {
    // Carica il nome dalle impostazioni
    @AppStorage("fakeCallName") private var fakeCallName = "Sconosciuto"
    
    @Environment(\.dismiss) var dismiss
    
    // Per gestire l'audio
    @State private var audioPlayer: AVAudioPlayer?
    @State private var callStatus = "Chiamata in arrivo..."
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
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
                
                // Pulsanti di fine chiamata
                Button(action: {
                    audioPlayer?.stop() // Ferma l'audio
                    dismiss() // Chiude la vista
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
            // Logica della chiamata
            playRingAndRecording()
        }
    }
    
    func playRingAndRecording() {
        // --- 1. Simula 3 secondi di squillo ---
        callStatus = "Squillo..."
        
        // (Qui potresti riprodurre un file "ringtone.mp3")
        // Per semplicità, usiamo un timer
        
        Task {
            try? await Task.sleep(nanoseconds: 3 * 1_000_000_000) // 3 secondi
            
            // --- 2. Avvia la registrazione personalizzata ---
            callStatus = "Connesso"
            
            // Prova a caricare e riprodurre la registrazione
            // (Assicurati di avere un file "recording.m4a" nel tuo progetto)
            if let path = Bundle.main.path(forResource: "recording", ofType: "m4a") {
                do {
                    // Configura la sessione audio per riprodurre in modalità altoparlante (come una chiamata)
                    try AVAudioSession.sharedInstance().setCategory(.playback, mode: .voiceCall)
                    try AVAudioSession.sharedInstance().setActive(true)
                    
                    audioPlayer = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
                    audioPlayer?.play()
                } catch {
                    print("Errore nel caricare la registrazione: \(error.localizedDescription)")
                    callStatus = "Errore audio"
                }
            } else {
                print("File 'recording.m4a' non trovato.")
                callStatus = "File audio non trovato"
            }
        }
    }
}


// MARK: - 7. Vista Impostazioni

struct SettingsView: View {
    @AppStorage("fakeCallName") private var fakeCallName = "Sconosciuto"
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Impostazioni Finta Chiamata")) {
                    TextField("Nome chiamante", text: $fakeCallName)
                    
                    Button("Registra Audio Personalizzato") {
                        // In un'app reale, qui avvieresti AVAudioRecorder
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
