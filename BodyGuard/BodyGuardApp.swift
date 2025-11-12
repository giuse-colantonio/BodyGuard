//
//  bodiiiiiiiApp.swift
//  bodiiiiiii
//
//  Created by Salvatore Arpaia on 07/11/25.
//

import SwiftUI
import SwiftData
@main
struct BODYGUARDApp: App {
    @StateObject private var routeManager = RouteManager()

    var body: some Scene {
        WindowGroup {
            if #available(iOS 26.0, *) {
                AppTabContainer()
                    .environmentObject(routeManager)
                    .modelContainer(for: [Contact.self])
            } else {
                ContentView()
                    .environmentObject(routeManager)
                    .modelContainer(for: [Contact.self]) 
            }
        }
    }
}
