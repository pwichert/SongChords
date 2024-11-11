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

    @State private var viewModel: ViewModel = ViewModel()
    
    var body: some Scene {
        #if os(macOS)
        Window ("SongChords", id: "main") {
            ContentView()
                .environment(viewModel)
        }
        .modelContainer(sharedModelContainer)
        #else
        WindowGroup {
            ContentView()
                .environment(viewModel)
        }
        .modelContainer(sharedModelContainer)
        #endif
    }
}
