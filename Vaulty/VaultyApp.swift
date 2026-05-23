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
    @AppStorage(VaultTheme.appearanceKey) private var appearanceRawValue = VaultAppearance.system.rawValue

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
                .preferredColorScheme(selectedAppearance.colorScheme)
                .tint(VaultTheme.accent)
        }
        .modelContainer(sharedModelContainer)
    }

    private var selectedAppearance: VaultAppearance {
        VaultAppearance(rawValue: appearanceRawValue) ?? .system
    }
}
