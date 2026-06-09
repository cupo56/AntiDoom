//  SharedStore.swift
//  Builds the SwiftData ModelContainer in the shared App Group container so the
//  main app and the extensions read/write the same database.

import Foundation
import SwiftData

enum SharedStore {
    static let appGroupID = "group.antidoom.AntiDoom"

    @MainActor
    static let container: ModelContainer = {
        let schema = Schema([FoundationProbe.self])
        let configuration = ModelConfiguration(
            schema: schema,
            groupContainer: .identifier(appGroupID)
        )
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create shared ModelContainer: \(error)")
        }
    }()
}
