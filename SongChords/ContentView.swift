//
//  ContentView.swift
//  SongChords
//
//  Created by Peter Wichert on 07.11.24.
//

import SwiftUI

struct ContentView: View {
    @State private var visibility: NavigationSplitViewVisibility = .all
    @State private var selectedPlaylist: PlayList?
    @State private var selectedSongs: Set<Song> = []

    @Environment(ViewModel.self) private var viewModel

    var body: some View {
        NavigationSplitView(columnVisibility: $visibility) {
            
            PlayListView(selectedPlaylist: $selectedPlaylist, visibility: $visibility).environment(viewModel)

        } content: {
            
            if let selectedPlaylist = selectedPlaylist {
                SongListView(playlist: selectedPlaylist, visibility: $visibility, selectedSongs: $selectedSongs).environment(viewModel)
            } else {
                ContentUnavailableView("Select a playlist", systemImage: "doc.text.image.fill")
            }
            
        } detail: {
            
            if selectedSongs.count == 1, let selected = selectedSongs.first {
                SongView(song: selected, visibility: $visibility).environment(viewModel)
            } else {
                ContentUnavailableView("Select a song", systemImage: "doc.text.image.fill")
            }
            
        }
        .onChange(of: selectedPlaylist) { selectedSongs = [] }
        .navigationSplitViewStyle(.automatic)
        .preferredColorScheme(viewModel.displayMode == .dark ? .dark : (viewModel.displayMode == .light ? .light : nil))
    }
}
