//  AntiDoomApp.swift
//  AntiDoom

import SwiftUI
import SwiftData

@main
struct AntiDoomApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(SharedStore.container)
    }
}
