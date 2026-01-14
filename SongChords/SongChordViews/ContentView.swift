//
//  ContentView.swift
//  SongChords
//
//  Created by Peter Wichert on 07.11.24.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var visibility: NavigationSplitViewVisibility = .all
    @State private var selectedPlaylistID: PersistentIdentifier?
    @State private var selectedSongIDs: Set<PersistentIdentifier> = []
    @State private var showAlert: Bool = false

    @Environment(UserSettings.self) private var userSettings
    @Environment(AudioPlayer.self) private var audioPlayer
    @Environment(Globals.self) private var globals
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationSplitView(columnVisibility: $visibility) {
            
            // Sidebar – Playlists
            PlayListView(
                selectedPlaylistID: $selectedPlaylistID, visibility: $visibility
            )
            .environment(userSettings)
            .environment(globals)
            .environment(audioPlayer)
            
        } content: {
            
            // Mittlere Spalte – Songs
            if let playlistID = selectedPlaylistID {
                SongListView(
                    playlistID: playlistID,
                    visibility: $visibility,
                    selectedSongIDs: $selectedSongIDs
                )
                .environment(userSettings)
                .environment(globals)
                .environment(audioPlayer)
                
            } else {
                ContentUnavailableView("Select a playlist", systemImage: "doc.text.image.fill")
            }
            
        } detail: {
            
            // Detail – Song
            if let songID = selectedSongIDs.first {
                SongView(songID: songID, visibility: $visibility)
                    .environment(userSettings)
                    .environment(globals)
                    .environment(audioPlayer)
                
            } else {
                ContentUnavailableView("Select a song", systemImage: "doc.text.image.fill")
            }
        }
        .alert((globals.songChordsError?.error as? SongChordsError)?.desc ?? globals.songChordsError?.error.localizedDescription ?? "??", isPresented: $showAlert) {
            Button("Ok") { }
        }
        .onChange(of: globals.songChordsError) { showAlert.toggle() }
        .onChange(of: selectedPlaylistID) { selectedSongIDs = [] }      // ContentUnavailable in SongView
        .navigationSplitViewStyle(.automatic)
        .preferredColorScheme(userSettings.displayMode == .dark ? .dark : (userSettings.displayMode == .light ? .light : nil))
    }
}

//struct PlaylistSidebarView: View {
//    @Binding var selection: PersistentIdentifier?
//
//    @Query(sort: \PlayList.title)
//    private var playlists: [PlayList]
//
//    var body: some View {
//        List(playlists, selection: $selection) { playlist in
//            Text(playlist.title)
//        }
//        .navigationTitle("Playlists")
//    }
//}
//
//struct SongListView_: View {
//    let playlistID: PersistentIdentifier?
//    @Binding var selection: Set<PersistentIdentifier>
//
//    @Query private var songs: [Song]
//
//    init(playlistID: PersistentIdentifier?, selection: Binding<Set<PersistentIdentifier>>) {
//        self.playlistID = playlistID
//        self._selection = selection
//
//        if let playlistID {
//            _songs = Query(
//                filter: #Predicate<Song> {
//                    $0.playlist?.persistentModelID == playlistID
//                },
//                sort: \Song.title
//            )
//        } else {
//            _songs = Query(filter: #Predicate<Song> { _ in false })
//        }
//    }
//
//    var body: some View {
//        List(songs, selection: $selection) { song in
//            Text(song.title)
//        }
//        .navigationTitle("Songs")
//    }
//}
//
//struct SongDetailContainer: View {
//    let songID: PersistentIdentifier
//    @Binding var visibility: NavigationSplitViewVisibility
//
//    @Query private var songs: [Song]
//
//    init(songID: PersistentIdentifier, visibility: Binding<NavigationSplitViewVisibility>) {
//        self.songID = songID
//        self._visibility = visibility
//        
//        _songs = Query(
//            filter: #Predicate<Song> {
//                $0.persistentModelID == songID
//            }
//        )
//    }
//
//    var body: some View {
//        if let song = songs.first {
////            SongDetailView(
//                SongView(
//                song: song, visibility: $visibility
//            )
//                .onChange(of: song.persistentModelID, initial: true) {
//                    let rep = song.representationHolder
//                    let src = song.srcText
//                    Task {
//                        await SongTaskManagerII.shared.processSongInBackground(representationHolder: rep, srcText: src, transpose: 0, showHeader: true, showText: true, userSettings: UserSettings())
//                    }
//                }
//        } else {
//            ContentUnavailableView(
//                "Song nicht gefunden",
//                systemImage: "music.note"
//            )
//        }
//    }
//}
//
//struct SongDetailView: View {
//    let song: Song
//    @Binding var visibility: NavigationSplitViewVisibility
//
//    var body: some View {
//        ScrollView([.horizontal, .vertical], showsIndicators: false) {
//            VStack(alignment: .leading) {
//                DetailContent(song: song, representationHolder: song.representationHolder)
//            }
//        }
//        .navigationTitle(song.title)
//        .onChange(of: song.persistentModelID, initial: true) {
//            Task {
//                await SongTaskManagerII.shared.processSongInBackground(representationHolder: song.representationHolder, srcText: song.srcText, transpose: 0, showHeader: true, showText: true, userSettings: UserSettings())
//            }
//        }
//    }
//}

