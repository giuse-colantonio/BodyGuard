//
//  Untitled.swift
//  BodyGuard
//
//  Created by AFP Student 33 on 08/11/25.
//
import SwiftUI
import SwiftData

@available(iOS 26.0, *)
struct AppTabContainer: View {
    @State private var searchText: String = ""

    var body: some View {
        TabView {
            Tab("Map", systemImage: "map.fill") {
                ContentView()
            }

            Tab("Contacts", systemImage: "person.2.fill") {
                NavigationStack {
                                   ContactsListView() // From your SwiftData contacts feature
                               }
            }

            Tab("Profile", systemImage: "person.fill") {
                Text("Profile Screen")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
            }

            Tab(role: .search) {
                NavigationStack {
                    // Drive the search screen from the TabView’s search pill
                    SearchIntegratedMapView(searchText: $searchText)
                }
            }
        }
        // Only visible on the search tab; still fine to keep globally on TabView
        .searchable(text: $searchText, prompt: "Search places or addresses")
    }
}

#Preview {
        // Inject RouteManager so any child views that use @EnvironmentObject RouteManager won’t crash.
        AppTabContainer()
            .environmentObject(RouteManager())
}
