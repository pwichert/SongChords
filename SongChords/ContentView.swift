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

    @Environment(ViewModel.self) private var viewModel
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationSplitView(columnVisibility: $visibility) {

            PlayListView(selectedPlaylistID: $selectedPlaylistID, visibility: $visibility).environment(viewModel)

        } content: {
            
            if let selectedPlaylistID = selectedPlaylistID, let selectedPlaylist = PlayList.fetchPlaylists(with: [selectedPlaylistID], in: modelContext).first {
                SongListView(playlist: selectedPlaylist, visibility: $visibility, selectedSongIDs: $selectedSongIDs).environment(viewModel)
            } else {
                ContentUnavailableView("Select a playlist", systemImage: "doc.text.image.fill")
            }
            
        } detail: {
            
            if selectedSongIDs.count == 1, let selectedSongID = selectedSongIDs.first, let song = Song.fetchSongs(with: [selectedSongID], in: modelContext).first {
                SongView(song: song, visibility: $visibility).environment(viewModel)
            } else {
                ContentUnavailableView("Select a song", systemImage: "doc.text.image.fill")
            }
            
        }
        .onChange(of: selectedPlaylistID) { selectedSongIDs = [] }      // ContentUnavailable in SongView
        .navigationSplitViewStyle(.automatic)
        .preferredColorScheme(viewModel.displayMode == .dark ? .dark : (viewModel.displayMode == .light ? .light : nil))
    }
}
