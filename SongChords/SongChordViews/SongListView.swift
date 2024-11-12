//
//  SongListView.swift
//  SongChords
//
//  Created by Peter Wichert on 07.11.24.
//

import SwiftUI

struct SongListView: View {
    var playlist: PlayList  // Übergebene Playlist

    @Environment(\.modelContext) private var modelContext

    @State private var showSongEditView: Bool = false
    @State private var deleteIndexset: IndexSet?
    @State private var showDeleteAlert: Bool = false

    var body: some View {
        List {
            ForEach((playlist.songs?.sorted(by: { $0.seq < $1.seq }))!) { song in
                NavigationLink(song.title, destination: SongView(song: song))
                    .contextMenu {
                        Button("delete", role: .destructive) {
                            let indexOfSong = (playlist.songs ?? []).sorted(by: { $0.seq < $1.seq }).firstIndex { $0 === song }
                            if let indexOfSong = indexOfSong {
                                deleteIndexset = IndexSet()
                                deleteIndexset!.insert(indexOfSong)
                                showDeleteAlert.toggle()
                            }
                        }
                    }
            }
            .onMove(perform: moveSongs)
            .onDelete { indexSet in
                deleteIndexset = indexSet
                showDeleteAlert.toggle()
            }
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
        .confirmationDialog(Text("Delete Song"), isPresented: $showDeleteAlert, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let deleteIndexset = deleteIndexset {
                    deleteSongs(playlist: playlist, offsets: deleteIndexset)
                }
            }
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
    
    private func deleteSongs(playlist: PlayList, offsets: IndexSet) {
        if offsets.isEmpty || (playlist.songs ?? []).count == 0 { return }
        
        let sortedSongs = (playlist.songs ?? []).sorted(by: { $0.seq < $1.seq })
        for index in offsets {
            let s = sortedSongs[index]
            modelContext.delete(s)
            playlist.songs?.removeAll(where: { $0.seq == s.seq })
        }
    }
}
