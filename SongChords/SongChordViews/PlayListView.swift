//
//  PlayListView.swift
//  SongChords
//
//  Created by Peter Wichert on 07.11.24.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct PlayListView: View {
    @Binding var visibility: NavigationSplitViewVisibility
    
    @Environment(\.modelContext) private var modelContext
    @Environment(ViewModel.self) private var viewModel

    @State private var showPlaylistNewView: Bool = false
    @State private var showDeleteAlert: Bool = false
    @State private var selectedPlaylist: PlayList?
    
    @State private var showOptionsView: Bool = false
    @State private var showPrintOptionsView: Bool = false
    @State private var showInfoView: Bool = false
    @State private var showPrivacyView: Bool = false
    
    @State private var showPlaylistImport: Bool = false
    @State private var showSongImport: Bool = false
    @State private var openUrl: URL?

    @AppStorage("isOnboarding") var isOnboarding: Bool = true

    @Query(sort: \PlayList.seq, order: .forward) private var playlists: [PlayList]
    
    var body: some View {
        List {
            ForEach(playlists) { playlist in
                NavigationLink(playlist.title, destination: SongListView(playlist: playlist, visibility: $visibility).environment(viewModel))
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
            ToolbarItem {
                Button(action: { showPlaylistNewView.toggle() }, label: { Image(systemName: "plus") })
            }
#if os(iOS)
            ToolbarItem{//}(placement: .primaryAction) {
                EditButton()
            }
#endif
            
            ToolbarItem {
                Menu {
                    Button(action: { showOptionsView.toggle() }) {
                        Label("Options", systemImage: "gear.circle")
                    }
                    Button(action: { showPrintOptionsView.toggle() }) {
                        Label("PDF Options", systemImage: "printer")
                    }
                    Button(action: { showInfoView.toggle() }) {
                        Label("Info", systemImage: "info.circle")
                    }
                    Button(action: { showPrivacyView.toggle() }) {
                        Label("Privacy Policy", systemImage: "person.fill.questionmark")
                    }
                } label: {
                    Label("Options", systemImage: "ellipsis.circle")
                }
            }
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
        }
        .sheet(isPresented: $showPrivacyView) {
            NavigationStack {
                PrivacyView()
            }
        }
        .sheet(isPresented: $isOnboarding) {
            NavigationStack {
                OnboardingSheet()
            }
        }
        .sheet(isPresented: $showSongImport) {
            NavigationStack {
                PlaylistSelectionSheet(playlists: playlists, urlToInsert: openUrl)
            }
        }
        .onOpenURL(perform: { url in
            print("onOpenURL: \(url)")
            let fileExtension = url.pathExtension
            openUrl = url
            
            if fileExtension.lowercased() == (UTType.playlistJSON.preferredFilenameExtension ?? "nix").lowercased() {
                showPlaylistImport.toggle()
            } else if fileExtension.lowercased() == (UTType.songJSON.preferredFilenameExtension ?? "nix").lowercased() {
                showSongImport.toggle()
            }
        })
        .alert("Playlist must be empty", isPresented: $showDeleteAlert) {
            Button("Ok") {
            }
        }
        .confirmationDialog(Text("Import Playlist?"), isPresented: $showPlaylistImport, titleVisibility: .visible) {
            Button("Import") {
                withAnimation {
                    if let openUrl = openUrl {
                        importPlaylist(url: openUrl)
                        openUrl.stopAccessingSecurityScopedResource()
                    }
                }
            }
        }
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
    
    private func importPlaylist(url: URL?) {
        if let url = url {
            do {
                let result = url.startAccessingSecurityScopedResource()
                if result {
                    let playlist = try PlayList.playlistFromData(url: url)
                    url.stopAccessingSecurityScopedResource()

                    let newPlaylist = PlayList(modelContext: modelContext, title: playlist.title)
                    modelContext.insert(newPlaylist)
                    newPlaylist.songs = []
            
                    for song in (playlist.songs ?? []) {
                        modelContext.insert(song)
                        song.toPlaylist(playlist: newPlaylist)
                    }
                }
            } catch {
                print(error)
            }
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
        .navigationTitle(playlist == nil ? "New Playlist" : "Edit Playlist")
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
                .disabled(playlistTitle.isEmpty || !PlayList.isValidPlaylistTitle(playlistTitle))
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

struct PlaylistSelectionSheet: View {
    let playlists: [PlayList]
    let urlToInsert: URL?
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
        
    var body: some View {
        List(playlists) { playlist in
            Button(action: {
                do {
                    if let url = urlToInsert {
                        let result = url.startAccessingSecurityScopedResource()
                        if result {
                            let song = try Song.songFromData(url: url)
                            url.stopAccessingSecurityScopedResource()
                            
                            let newSong = Song(title: song.title)
                            modelContext.insert(newSong)
                            newSong.toPlaylist(playlist: playlist)
                            newSong.updateFromSong(other: song)
                        }
                    }
                } catch {
                    print(error)
                }
                
                dismiss()
            }) {
                Text(playlist.title)
            }
        }
        .navigationTitle("Import Song into Playlist")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
    }
}

struct OnboardingSheet: View {
    @Environment(\.dismiss) var dismiss
        
    var body: some View {
        Form {
            VStack(alignment: .center) {
                HStack {
                    Image("AppIconInternal")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(10)
             
                    Text("For a brief introduction, please refer to menu item 'Info'.").padding(10)
                }
            }
        }
        #if os(macOS)
        .frame(minHeight: 200)
        #endif
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Ok") {
                    dismiss()
                }
            }
        }
    }
}

struct PrivacyView: View {
    @Environment(ViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Form {
            Text(
            """
            What data is collected?
                    
            'SongChords' does not collect any user-related data. Neither the developer nor third parties receive data from this app, ensuring the user’s privacy is preserved.
                    
            When using the app, only data necessary for its functionality is stored. This includes, for example, the names of songs and playlists. Users enter this data themselves while using the app, making the type and scope of the data transparent and apparent.
                    
            In addition to being stored on the device, the data is also saved in iCloud to enable easy restoration of data when switching devices or synchronization across multiple devices. This feature requires an Apple account, iCloud to be enabled, and an internet connection.
                    
            No user-specific accounts are used or created within the app.
                    
            No data is used for tracking purposes.
                    
            No data is shared with advertising networks.
                    
            To better understand how this app is used and to improve it, the developer utilizes analytics information provided by the App Store. This service handles generic information and statistics that are anonymized and do not allow any personal conclusions about the user. Such analytics may include the number of installations and crashes.
                    
            Additionally, it should be noted that both data storage and the app operate on platforms provided by a vendor based in the United States. It cannot be ruled out, and we have no control over, the possibility that this vendor processes data from the app’s user in the United States. We have no knowledge of, nor any influence on, what data may be involved or for what purpose this processing occurs.
            """)
            #if os(iOS)
            .font(.footnote)
            #endif
        }
        #if os(macOS)
        .padding()
        #endif
        .navigationTitle("Privacy Policy")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Ok") {
                    dismiss()
                }
            }
        }
    }
}
