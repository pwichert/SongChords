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
    @State private var showStore: Bool = false

    @Environment(UserSettings.self) private var userSettings
    @Environment(Globals.self) private var globals
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationSplitView(columnVisibility: $visibility) {

            PlayListView(selectedPlaylistID: $selectedPlaylistID, visibility: $visibility)
                .environment(userSettings)
                .environment(globals)

        } content: {
            
            if let selectedPlaylistID = selectedPlaylistID, let selectedPlaylist = PlayList.fetchPlaylist(with: selectedPlaylistID, in: modelContext) {
                SongListView(playlist: selectedPlaylist, visibility: $visibility, selectedSongIDs: $selectedSongIDs)
                    .environment(userSettings)
                    .environment(globals)
            } else {
                ContentUnavailableView("Select a playlist", systemImage: "doc.text.image.fill")
            }
            
        } detail: {
            
            if selectedSongIDs.count == 1, let selectedSongID = selectedSongIDs.first, let song = Song.fetchSong(with: selectedSongID, in: modelContext) {
                SongView(song: song, visibility: $visibility)
                    .environment(userSettings)
                    .environment(globals)
            } else {
                ContentUnavailableView("Select a song", systemImage: "doc.text.image.fill")
            }
            
        }
        .alert((globals.songChordsError?.error as? SongChordsError)?.desc ?? globals.songChordsError?.error.localizedDescription ?? "??", isPresented: $showAlert) {
            Button("Ok") { }
        }
        .alert(SongChordsError.limitReached.desc, isPresented: $showStore) {
            // Hier die View zum Kaufen starten
            Button("Ok, ich überleg's mir") { }
        }
        .onChange(of: globals.songChordsError) { globals.songChordsError?.error as? SongChordsError == SongChordsError.limitReached ? showStore.toggle() : showAlert.toggle() }
        .onChange(of: selectedPlaylistID) { selectedSongIDs = [] }      // ContentUnavailable in SongView
        .navigationSplitViewStyle(.automatic)
        .preferredColorScheme(userSettings.displayMode == .dark ? .dark : (userSettings.displayMode == .light ? .light : nil))
    }
}
