//
//  VaultyApp.swift
//  Vaulty
//
//  Created by Sukhman Singh on 5/23/26.
//

import SwiftUI
import SwiftData

@main
struct VaultyApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            VaultPhoto.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
