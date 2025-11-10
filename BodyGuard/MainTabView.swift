//
//  Untitled.swift
//  BodyGuard
//
//  Created by AFP Student 33 on 08/11/25.
//
import SwiftUI

@available(iOS 26.0, *)
struct AppTabContainer: View {
    @State private var searchText: String = ""

    var body: some View {
        TabView {
            Tab("Map", systemImage: "map.fill") {
                ContentView()
            }

            Tab("Teams", systemImage: "person.3.fill") {
                Text("Teams Screen")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
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
