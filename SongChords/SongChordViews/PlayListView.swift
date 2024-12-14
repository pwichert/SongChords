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
                    .dropDestination(for: Song.self) { receivedSongs, location in
                        for song in receivedSongs {
                            print(".dropDestination: received \(song.title) for playlist \(playlist.title)")
                            song.toPlaylist(playlist: playlist, move: true)
                        }
                        
                        return true
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
                    #if DEBUG
                    Button(action: { printAll() }) {
                        Label("Print All", systemImage: "list.number")
                    }
                    #endif
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
                        song.toPlaylist(playlist: newPlaylist, move: false)
                    }
                }
            } catch {
                print(error)
            }
        }
    }
    
    private func printAll() {
        var cnt1: Int = 0
        for p in playlists {
            for s in (p.songs ?? []).sorted(by: { a, b in a.seq < b.seq }) {
                cnt1 += 1
                print("\(p.title) \(s.seq) \(s.title)")
            }
        }
        
        print("\(cnt1) Songs in Playlisten ----------")
        
        let allSongs = try! modelContext.fetch(FetchDescriptor<Song>())
        
        var cnt2 = 0
        for s in allSongs.sorted(by: { a, b in a.seq < b.seq }).filter({ $0.playlist == nil}) {
            cnt2 += 1
            print("nil \(s.seq) \(s.title)")
//            modelContext.delete(s)
        }

        print("\(cnt2) Songs NICHT in Playlisten ----------")
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
                            newSong.toPlaylist(playlist: playlist, move: false)
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
            .buttonStyle(.plain)
        }
        #if os(macOS)
        .frame(idealHeight: 400)
        #endif
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
        InfoView()
    }
}

struct PrivacyTextView: View {
    var body: some View {
        Text(
        """
        We, the SongChords team, take the protection of your personal data very seriously. This privacy policy explains how we collect, use, store, and protect your data when you use our app.

        1. Data Controller

        The responsible party for data processing is:

        Peter Wichert
        Brockenscheidter Straße 15c
        45731 Waltrop
        Phone: +49 2309 569304
        Email: sc_app@icloud.com

        2. Data Collected

        a) Automatically collected data:

        • Usage data: Information about the use of the app, such as device information, operating system version, and error logs.

        • Analytics data: Anonymized usage data may be collected to improve the app (e.g., crash reports).

        b) User-provided data:

        • Song data: Song lyrics, chords, playlists, and other content you create or store in the app. These data are solely for the app’s functionality and are not accessible to us.

        • iCloud synchronization: If enabled, your data is stored in your iCloud account.

        3. Use of Data

        Your data is used exclusively for the following purposes:

        • Providing and improving app functionality.

        • Synchronizing your data between your devices via iCloud.

        • Fixing bugs and optimizing app performance.

        4. Data Sharing

        We do not share your personal data with third parties unless:

        • You have explicitly consented.

        • We are legally obligated to do so.

        • It is necessary to provide technical services (e.g., iCloud by Apple).

        No data is used for tracking purposes. No data is shared with advertising networks.

        5. iCloud Synchronization

        The iCloud synchronization is provided by Apple. Your data is securely stored and encrypted in your personal iCloud account. Please refer to Apple’s Privacy Policy as Apple is responsible for processing your data in connection with iCloud usage.

        6. Data Security

        We implement technical and organizational measures to protect your data from unauthorized access, loss, or misuse.

        7. Your Rights

        You have the right to:

        • Access the data we store about you.

        • Request the correction of incorrect data.

        • Request the deletion of your data, provided there are no legal retention requirements.

        Please contact us at: sc_app@icloud.com

        8. Changes to the Privacy Policy

        We reserve the right to update this privacy policy if necessary. Changes will be published in the app or on our website.

        9. Contact

        If you have any questions or concerns regarding privacy, please contact us at:

        sc_app@icloud.com

        Last updated: December 2024
        """)
    }
}

struct PrivacyView: View {    
    var body: some View {
        InfoContentView("Datenschutz") {
            PrivacyTextView()
        }
    }
}
