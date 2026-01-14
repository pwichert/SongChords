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
    @Environment(\.scenePhase) private var scenePhase
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Song.self, PlayList.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            let result = try ModelContainer(for: schema, configurations: [modelConfiguration])
            GlobalModelContainer.shared = result
            return result
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    @State private var userSettings: UserSettings = UserSettings()
    @State private var globals: Globals = Globals()
    @State private var audioPlayer = AudioPlayer()
    
    var body: some Scene {
        #if os(macOS)
        Window ("SongChords", id: "main") {
            ContentView()
                .environment(userSettings)
                .environment(globals)
                .environment(audioPlayer)
                .task(id: scenePhase) {
                    await scenePhaseChanged(scenePhase)
                }
        }
        .modelContainer(sharedModelContainer)
        #else
        WindowGroup {
            ContentView()
                .environment(userSettings)
                .environment(globals)
                .environment(audioPlayer)
                .task(id: scenePhase) {
                    await scenePhaseChanged(scenePhase)
                }
        }
        .modelContainer(sharedModelContainer)
        #endif
    }
    
    private func scenePhaseChanged(_ phase: ScenePhase) async {
        if scenePhase == .active {
            print("-> active")
        } else {
            if scenePhase == .background { print("-> background")
                audioPlayer.stop()
                MarkerTimer.shared.stop()
            }
        }
    }
}
