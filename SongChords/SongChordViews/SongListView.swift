//
//  SongListView.swift
//  SongChords
//
//  Created by Peter Wichert on 07.11.24.
//

import SwiftUI

struct SongListView: View {
    var playlist: PlayList  // Übergebene Playlist
    
    @State private var showSongEditView: Bool = false
    
    var body: some View {
        List {
            ForEach((playlist.songs?.sorted(by: { $0.seq < $1.seq }))!) { song in
                NavigationLink(song.title, destination: SongView(song: song))
            }
            .onMove(perform: moveSongs)
        }
        .navigationTitle(playlist.title)
        .toolbar {
            ToolbarItem {
                Button(action: { showSongEditView.toggle() }, label: { Image(systemName: "plus") })
            }
            #if os(iOS)
            ToolbarItem(placement: .primaryAction) {
                EditButton()
            }
            #endif
        }
        .sheet(isPresented: $showSongEditView) {
            NavigationStack {
                SongEditView(playlist: playlist, song: nil)
            }
            .interactiveDismissDisabled()
        }
    }
    
    private func moveSongs(from source: IndexSet, to destination: Int) {
        var sortedSongs = (playlist.songs ?? []).sorted(by: { $0.seq < $1.seq })
        
        // Die Song-Reihenfolge anpassen
        sortedSongs.move(fromOffsets: source, toOffset: destination)
        
        // Die seq-Werte entsprechend der neuen Reihenfolge aktualisieren
        for index in sortedSongs.indices {
            if sortedSongs[index].seq != index { sortedSongs[index].seq = index }
        }
        
        playlist.songs = sortedSongs
    }
}
