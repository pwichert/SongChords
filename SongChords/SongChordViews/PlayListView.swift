//
//  PlayListView.swift
//  SongChords
//
//  Created by Peter Wichert on 07.11.24.
//

import SwiftUI
import SwiftData

struct PlayListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ViewModel.self) private var viewModel

    @State private var showPlaylistNewView: Bool = false
    @State private var showDeleteAlert: Bool = false
    @State private var selectedPlaylist: PlayList?
    
    @State private var showOptionsView: Bool = false
    @State private var showPrintOptionsView: Bool = false
    @State private var showInfoView: Bool = false
    
    @Query(sort: \PlayList.seq, order: .forward) private var playlists: [PlayList]
    
    var body: some View {
        List {
            ForEach(playlists) { playlist in
                NavigationLink(playlist.title, destination: SongListView(playlist: playlist).environment(viewModel))
                    .contextMenu {
                        Button("Rename") {
                            selectedPlaylist = playlist
                        }
                        Button("Delete", role: .destructive) {
                            if !deletePlaylist(playlist: playlist) {
                                showDeleteAlert.toggle()
                            }
                        }
                    }
            }
            .onDelete { indexSet in
                if !deletePlaylists(offsets: indexSet) {
                    showDeleteAlert.toggle()
                }
            }
            .onMove(perform: movePlaylists)
        }
        .navigationTitle("Playlists")
        .toolbar {
            ToolbarItemGroup {
                Button(action: { showPlaylistNewView.toggle() }, label: { Image(systemName: "plus") })
            
                // Menü-Button
                Menu {
                    Button(action: { showOptionsView.toggle() }) {
                        Label("Options", systemImage: "gear.circle")
                    }
                    Button(action: { showPrintOptionsView.toggle() }) {
                        Label("PDF Options", systemImage: "printer")
                    }
                    Button(action: { showInfoView.toggle() }) {
                        Label("Info", systemImage: "gear.circle")
                    }
                } label: {
                    Label("Options", systemImage: "ellipsis.circle")
                }
                .menuStyle(BorderlessButtonMenuStyle())  // Optional: Menü-Stil für macOS
            }
            
            #if os(iOS)
            ToolbarItem(placement: .primaryAction) {
                EditButton()
            }
            #endif
        }
        .sheet(item: $selectedPlaylist) { pl in
            NavigationStack {
                PlaylistEditView(playlist: pl)
            }
            .interactiveDismissDisabled()
        }
        .sheet(isPresented: $showPlaylistNewView) {
            NavigationStack {
                PlaylistEditView(playlist: nil)
            }
            .interactiveDismissDisabled()
        }
        .sheet(isPresented: $showOptionsView) {
            NavigationStack {
                OptionsView()
            }
            .interactiveDismissDisabled()
        }
        .sheet(isPresented: $showPrintOptionsView) {
            NavigationStack {
                PrintOptionsView()
            }
            .interactiveDismissDisabled()
        }
        .sheet(isPresented: $showInfoView) {
            NavigationStack {
                InfoView()
            }
            .interactiveDismissDisabled()
        }
        .alert(isPresented: $showDeleteAlert, content: {
            Alert(title: Text("Info"),
                  message: Text("Playlist must be empty"),
                  dismissButton: Alert.Button.default (
                    Text("Ok"), action: {
                    }
                  )
            )
        })
    }
    
    private func deletePlaylist(playlist: PlayList) -> Bool {
        if (playlist.songs ?? []).count > 0 { return false }
        
        modelContext.delete(playlist)
        return true
    }
    
    private func deletePlaylists(offsets: IndexSet) -> Bool {
        if offsets.isEmpty { return true }
        
        let sortedPlaylists = playlists
        
        for index in offsets {
            if (sortedPlaylists[index].songs ?? []).count == 0 {
                modelContext.delete(sortedPlaylists[index])
            } else {
                return false
            }
        }
        
        return true
    }
    
    private func movePlaylists(indices: IndexSet, newOffset: Int) {
        if indices.isEmpty { return }
        
        var sortedPlaylists = playlists
        sortedPlaylists.move(fromOffsets: indices, toOffset: newOffset)
        
        // Die seq-Werte entsprechend der neuen Reihenfolge aktualisieren
        for index in sortedPlaylists.indices {
            if sortedPlaylists[index].seq != index { sortedPlaylists[index].seq = index }
        }
    }
}

struct PlaylistEditView: View {
    let playlist: PlayList?
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var playlistTitle: String = ""

    var body: some View {
        Form {
            TextField("Title", text: $playlistTitle)
                .autocorrectionDisabled()
        }
        #if os(macOS)
        .padding()
        #endif
        .navigationTitle("\(playlist == nil ? "new" : "edit") Playlist")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    if let playlist {
                        if playlist.title != playlistTitle { playlist.title = playlistTitle }
                    } else {
                        let playlist = PlayList(modelContext: modelContext, title: playlistTitle, songs: [])
                        modelContext.insert(playlist)
                    }
                    dismiss()
                }
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
        .onAppear {
            if let playlist {
                playlistTitle = playlist.title
            }
        }
    }
}
