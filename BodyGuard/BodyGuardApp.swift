//
//  bodiiiiiiiApp.swift
//  bodiiiiiii
//
//  Created by Salvatore Arpaia on 07/11/25.
//

import SwiftUI

@main
struct BODYGUARDApp: App {
    // Shared RouteManager for the whole app
    @StateObject private var routeManager = RouteManager()

    var body: some Scene {
        WindowGroup {
            if #available(iOS 26.0, *) {
                AppTabContainer()
                    .environmentObject(routeManager)
            } else {
                // Fallback UI if AppTabContainer is iOS 26-only
                ContentView()
                    .environmentObject(routeManager)
            }
        }
    }
}

