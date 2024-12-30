//
//  SongChordsApp.swift
//  SongChords
//
//  Created by Peter Wichert on 07.11.24.
//

import SwiftUI
import SwiftData

@main
struct SongChordsApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Song.self, PlayList.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    @State private var userSettings: UserSettings = UserSettings()
    @State private var globalError: GlobalError = GlobalError()

    var body: some Scene {
        #if os(macOS)
        Window ("SongChords", id: "main") {
            ContentView()
                .environment(userSettings)
                .environment(globalError)
        }
        .modelContainer(sharedModelContainer)
        #else
        WindowGroup {
            ContentView()
                .environment(userSettings)
                .environment(globalError)
        }
        .modelContainer(sharedModelContainer)
        #endif
    }
}
