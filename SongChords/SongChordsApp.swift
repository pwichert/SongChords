//
//  SongChordsApp.swift
//  SongChords
//
//  Created by Peter Wichert on 07.11.24.
//

/*
Hello Review Team,

The app SongChords is used to manage playlists and songs for musicians. Each song is displayed together with its corresponding chords and lyrics.

I have added a demo playlist to the information section of the app. It contains several example songs.
The demo playlist can be imported by drag and drop on macOS or simply by tapping the file on iOS, as long as SongChords is installed.

One of the songs in the playlist shows a visible “note” icon. This means that the song is linked to an audio track, which can be played using the built-in player if an Apple Music  subscription is available. This song also contains two player loops, which allow sections of the song to be looped during playback.

In addition, in the new Autoscroll mode, the song headers (Verse, Chorus, etc.) display a time value. When Autoscroll is enabled, the song automatically scrolls to the next section when the displayed time is reached during playback or timer. The built-in timer also enables Autoscroll for users without an Apple Music subscription.

Best regards,
Peter
 
Anhang: Setlist Concert.scplaylist
*/

                
                
                
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
