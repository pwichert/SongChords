//
//  PlayListView.swift
//  SongChords
//
//  Created by Peter Wichert on 07.11.24.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// Identifiable Wrapper für URL
// für PlaylistSelectionSheet(), um das sheet sicher über "item:" auszulösen
struct IdentifiableURL: Identifiable {
    let id: UUID = UUID() // Eine eindeutige ID
    let url: URL // Die enthaltene URL
}

struct PlayListView: View {
    @Binding var selectedPlaylistID: PersistentIdentifier?
    @Binding var visibility: NavigationSplitViewVisibility
    
    @Environment(\.modelContext) private var modelContext
    @Environment(Globals.self) private var globals
    @Environment(SongChordsStore.self) private var store

    #if os(iOS)
    @State private var editMode: EditMode = .inactive
    #endif
    
    @State private var showPlaylistNewView: Bool = false
    @State private var renamePlaylist: PlayList?

    @State private var showOptionsView: Bool = false
    @State private var showPrintOptionsView: Bool = false
    @State private var showInfoView: Bool = false
    @State private var showPrivacyView: Bool = false
    
    @State private var showPlaylistImport: Bool = false
    @State private var songImportUrl: IdentifiableURL?
    @State private var openUrl: URL?
    
    @AppStorage("isOnboarding") var isOnboarding: Bool = true
    
    @Query(sort: \PlayList.seq, order: .forward) private var playlists: [PlayList]
    
    var body: some View {
        List(selection: $selectedPlaylistID) {
            ForEach(playlists) { playlist in
                Text(playlist.title)
                    .contextMenu {
                        Button("Rename") {
                            renamePlaylist = playlist
                        }
                        Button("Delete", role: .destructive) {
                            do {
                                try deletePlaylist(playlist: playlist)
                            } catch (let error) {
                                globals.setSongChordsError(error: error)
                            }
                        }
                    }
                    .dropDestination(for: Data.self) { receivedDatas, location in
                        do {
                            return try dropDestinationData(playlist: playlist, data: receivedDatas, modelContext: modelContext, store: store)
                        } catch(let error) {
                            globals.setSongChordsError(error: error)
                            return false
                        }
                    }
                    .dropDestination(for: Song.self) { receivedSongs, location in
                        do {
                            return try dropDestinationSongs(playlist: playlist, songs: receivedSongs, modelContext: modelContext, store: store)
                        } catch(let error) {
                            globals.setSongChordsError(error: error)
                            return false
                        }
                    }
            }
            .onDelete { indexSet in
                do {
                    try deletePlaylists(offsets: indexSet)
                } catch (let error) {
                    globals.setSongChordsError(error: error)
                }
            }
            .onMove(perform: movePlaylists)
        }
        .navigationTitle("Playlists")
        .toolbar {
            #if os(macOS)
            ToolbarItem {
                Button(action: { showPlaylistNewView.toggle() }, label: { Image(systemName: "plus.circle") }).help("New Playlist")
            }
            #else
            ToolbarItem(placement: .bottomBar) { // Fügt Menü unten hinzu
                if !isEditing {
                    HStack {
                        Spacer()
                        Button(action: { showPlaylistNewView.toggle() }, label: { Image(systemName: "plus.circle") })
                    }
                }
            }
            ToolbarItem {
                CustomEditButton(editMode: $editMode).id(UUID())
            }
            #endif
            ToolbarItem {
                if !isEditing {
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
        }
        .sheet(isPresented: $showPlaylistNewView) {
            NavigationStack {
                PlaylistEditView(playlist: nil)
            }
            .interactiveDismissDisabled()
        }
        .sheet(item: $renamePlaylist) { playlist in
            NavigationStack {
                PlaylistEditView(playlist: playlist)
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
        .sheet(item: $songImportUrl) { url in
            NavigationStack {
                PlaylistSelectionSheet(playlists: playlists, urlToInsert: url.url)
            }
        }
        .onOpenURL(perform: { url in
            print("onOpenURL: \(url)")
            let fileExtension = url.pathExtension
            openUrl = url
            
            if fileExtension.lowercased() == (UTType.playlistJSON.preferredFilenameExtension ?? "nix").lowercased() {
                showPlaylistImport.toggle()
            } else if fileExtension.lowercased() == (UTType.songJSON.preferredFilenameExtension ?? "nix").lowercased() {
                songImportUrl = IdentifiableURL(url: url)
            }
        })
        .confirmationDialog(Text("Import Playlist?"), isPresented: $showPlaylistImport, titleVisibility: .visible) {
            Button("Import") {
                withAnimation {
                    if let openUrl = openUrl {
                        do {
                            try importPlaylist(url: openUrl)
                        } catch (let error) {
                            globals.setSongChordsError(error: error)
                        }
                    }
                }
            }
        }
        #if os(iOS)
        .environment(\.editMode, $editMode)
        .onChange(of: editMode) { selectedPlaylistID = nil }
        #endif
    }
    
    private var isEditing: Bool {
        #if os(macOS)
        return false
        #else
        return editMode.isEditing
        #endif
    }
    
    private func deletePlaylist(playlist: PlayList) throws {
        if (playlist.songs ?? []).count > 0 { throw SongChordsError.playlistNotEmpty }
        
        modelContext.delete(playlist)
        try modelContext.save()
    }
    
    private func deletePlaylists(offsets: IndexSet) throws {
        if offsets.isEmpty { return }
        
        let sortedPlaylists = playlists
        for index in offsets {
            if (sortedPlaylists[index].songs ?? []).count == 0 {
                modelContext.delete(sortedPlaylists[index])
            } else {
                try modelContext.save()
                throw SongChordsError.playlistNotEmpty
            }
        }

        try modelContext.save()
    }
    
    private func movePlaylists(indices: IndexSet, newOffset: Int) {
        do {
            if indices.isEmpty { return }
            
            var sortedPlaylists = playlists
            sortedPlaylists.move(fromOffsets: indices, toOffset: newOffset)
            
            // Die seq-Werte entsprechend der neuen Reihenfolge aktualisieren
            for index in sortedPlaylists.indices {
                if sortedPlaylists[index].seq != index { sortedPlaylists[index].seq = index }
            }
            try modelContext.save()
        } catch (let error) {
            globals.setSongChordsError(error: error)
        }
    }
    
    private func importPlaylist(url: URL) throws {
        let playlist = try PlayList.fromUrl(url: url)
        let newPlaylist = try PlayList(modelContext: modelContext, title: playlist.title)
        modelContext.insert(newPlaylist)
        try newPlaylist.sortAndCopy(songs: playlist.songs, modelContext: modelContext, store: store)
        try modelContext.save()
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
            modelContext.delete(s)
        }

        print("\(cnt2) Songs waren NICHT in Playlisten ----------")
    }
}

struct PlaylistEditView: View {
    let playlist: PlayList?
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(Globals.self) private var globals

    @State private var playlistTitle: String = ""

    enum FocusedField: Hashable {
        case playlistTitle
    }
    @FocusState private var focusedField: FocusedField?

    var body: some View {
        Form {
            TextField("Title", text: $playlistTitle)
                .focused($focusedField, equals: .playlistTitle)
                .autocorrectionDisabled()
        }
        #if os(macOS)
        .padding()
        #endif
        .navigationTitle(playlist == nil ? "New Playlist" : "Edit Playlist")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    do {
                        if let playlist {
                            if playlist.title != playlistTitle { playlist.title = playlistTitle; try modelContext.save() }
                        } else {
                            let playlist = try PlayList(modelContext: modelContext, title: playlistTitle, songs: [])
                            modelContext.insert(playlist)
                            try modelContext.save()
                        }
                    } catch (let error) {
                        globals.setSongChordsError(error: error)
                    }
                    
                    dismiss()
                }
                .disabled(playlistTitle.isEmpty || !Song.isValidTitle(playlistTitle))
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
//        .defaultFocus($focusedField, .playlistTitle)
        .onAppear {
            #if os(iOS)
            focusedField = .playlistTitle
            #endif
            
            if let playlist {
                playlistTitle = playlist.title
            }
        }
    }
}

struct PlaylistSelectionSheet: View {
    let playlists: [PlayList]
    let urlToInsert: URL
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    @Environment(Globals.self) private var globals
    @Environment(SongChordsStore.self) private var store

    @State private var selectedPlaylist: PlayList.ID?

    var body: some View {
        List(playlists, selection: $selectedPlaylist) { playlist in
            Text(playlist.title)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    if let selectedPlaylist = selectedPlaylist {
                        if let pl = PlayList.fetchPlaylist(with: selectedPlaylist, in: modelContext) {
                            do {
                                let urlSong = try Song.fromUrl(url: urlToInsert)
                                let song = try Song(title: urlSong.title, modelContext: modelContext, store: store)
                                song.updateFromSong(other: urlSong)
                                song.toPlaylist(playlist: pl)
                                try modelContext.save()
                            } catch (let error) {
                                globals.setSongChordsError(error: error)
                            }
                        }
                    }
                    
                    dismiss()
                }) {
                    Text("Done")
                }.disabled(selectedPlaylist == nil)
            }
            ToolbarItem(placement: .cancellationAction) {
                Button(action: {
                    dismiss()
                }
                ) {
                    Text("Cancel")
                }
            }
        }
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #else
            .frame(idealHeight: 400)
        #endif
        .navigationTitle("Import Song into Playlist")
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
        The protection of your personal data is very important for us. This privacy policy explains how we collect, use, store, and protect your data when you use our app.

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

        Last updated: January 2025
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

#if os(iOS)
struct CustomEditButton: View {
    @Binding var editMode: EditMode
    
    var body: some View {
        Button(action: {
            toggleEditMode()
        }) {
            if $editMode.wrappedValue == .active {
                Label("Done", systemImage: "list.dash").labelStyle(.titleOnly)
            } else {
                Label("Done", systemImage: "list.dash").labelStyle(.iconOnly)
            }
        }
    }
    
    private func toggleEditMode() {
        withAnimation {
            if $editMode.wrappedValue == .active {
                $editMode.wrappedValue = .inactive
            } else {
                $editMode.wrappedValue = .active
            }
        }
    }
}
#endif
