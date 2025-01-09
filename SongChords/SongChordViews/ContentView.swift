//
//  ContentView.swift
//  SongChords
//
//  Created by Peter Wichert on 07.11.24.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    let store: SongChordsStore
    
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
                .environment(store)

        } content: {
            
            if let selectedPlaylistID = selectedPlaylistID, let selectedPlaylist = PlayList.fetchPlaylist(with: selectedPlaylistID, in: modelContext) {
                SongListView(playlist: selectedPlaylist, visibility: $visibility, selectedSongIDs: $selectedSongIDs)
                    .environment(userSettings)
                    .environment(globals)
                    .environment(store)
            } else {
                ContentUnavailableView("Select a playlist", systemImage: "doc.text.image.fill")
            }
            
        } detail: {
            
            if selectedSongIDs.count == 1, let selectedSongID = selectedSongIDs.first, let song = Song.fetchSong(with: selectedSongID, in: modelContext) {
                SongView(song: song, visibility: $visibility)
                    .environment(userSettings)
                    .environment(globals)
                    .environment(store)
            } else {
                ContentUnavailableView("Select a song", systemImage: "doc.text.image.fill")
            }
            
        }
        .alert((globals.songChordsError?.error as? SongChordsError)?.desc ?? globals.songChordsError?.error.localizedDescription ?? "??", isPresented: $showAlert) {
            Button("Ok") { }
        }
        .sheet(isPresented: $showStore) {
            NavigationStack {
                SongChordsStoreView(store: store, songChordsError: globals.songChordsError)
            }
        }
        .onChange(of: globals.songChordsError) { errorChanged() }
        .onChange(of: selectedPlaylistID) { selectedSongIDs = [] }      // ContentUnavailable in SongView
        .navigationSplitViewStyle(.automatic)
        .preferredColorScheme(userSettings.displayMode == .dark ? .dark : (userSettings.displayMode == .light ? .light : nil))
    }
    
    private func errorChanged() {
        // Falls es jemals weitere Purchases gibt, müsste die Liste für showStore.toggle() erweitert werden
        // Jeder Purchase wird von einem SongChordsError getriggert
        
        switch globals.songChordsError?.error as? SongChordsError {
        case .limitReached:
            showStore.toggle()
        default:
            showAlert.toggle()
        }
    }
}
