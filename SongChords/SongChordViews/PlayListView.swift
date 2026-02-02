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
    
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif

    #if os(iOS)
    @State private var editMode: EditMode = .inactive
    #endif
    
    @State private var showPlaylistNewView: Bool = false
    @State private var renamePlaylist: PlayList?

    @State private var showOptionsView: Bool = false
    @State private var showPrintOptionsView: Bool = false
    @State private var showInfoView: Bool = false
    @State private var showHelpView: Bool = false
    @State private var showPrivacyView: Bool = false
    @State private var showInsertDemoPlaylist: Bool = false
    
    @State private var songImportUrl: IdentifiableURL?
    @State private var playlistImportUrl: IdentifiableURL?
    
    @AppStorage("isOnboarding") private var isOnboarding: Bool = true

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
                    #if os(iOS)
                    // TODO: Drop von externen Dateien funktioniert in iOS nicht
                    // in iOS kann .dropDestination() scheinbar auch hier (innerhalb Liste) sein. Optisch ist das Ziel dann besser sichtbar
                    .dropDestination(for: SongDropTransferable.self) { receivedSongs, location in
                        do {
                            try dropDestinationItems(dropItems: receivedSongs, playlist: playlist, modelContext: modelContext)
                        } catch(let error) {
                            globals.setSongChordsError(error: error)
                        }
                    }
                    #endif
                    .draggable(PlayListTransferable(from: playlist, includeCodable: true, includeData: true)) { Text(playlist.title) }
            }
            #if os(macOS)
            .dropDestination(for: SongDropTransferable.self) { receivedSongs, location in
                do {
                    let playlist = playlists[max(0, location-1)]
                    try dropDestinationItems(dropItems: receivedSongs, playlist: playlist, modelContext: modelContext)
                } catch(let error) {
                    globals.setSongChordsError(error: error)
                }
            }
            #endif
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
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .toolbar {
            #if os(macOS)
            ToolbarItem {
                Button(action: { showPlaylistNewView.toggle() }, label: { Image(systemName: "plus.circle") }).help("New Playlist")
            }
            #else
            ToolbarSpacer(placement: .bottomBar)
                
            ToolbarItem(placement: .bottomBar) {
                Text("\(playlists.count) Playlists").font(.footnote)
                    .fixedSize(horizontal: true, vertical: false)   // ?? sonst clipped
            }
            .sharedBackgroundVisibility(.hidden)
                
            ToolbarSpacer(.flexible, placement: .bottomBar)
                
            ToolbarItem(placement: .bottomBar) {
                Button(action: { showPlaylistNewView.toggle() }, label: { Image(systemName: "plus.circle") })
            }
            
            ToolbarItem {
                EditButton()
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
                        
                        Button(action: { showInsertDemoPlaylist.toggle() }) {
                            Label("Create Demo Playlist", systemImage: "tray.and.arrow.down")
                        }

                        Button(action: { showPrivacyView.toggle() }) {
                            Label("Privacy Policy", systemImage: "person.fill.questionmark")
                        }

                        #if os(iOS)
                        Button(action: { showHelpView.toggle() }) {
                            Label("Help", systemImage: "book")
                        }
                        #else
                        Button(action: { openWindow(id: "help") }) {
                            Label("Help", systemImage: "book")
                        }
                        #endif

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
        .sheet(isPresented: $showPrivacyView) {
            NavigationStack {
                MarkdownResourceView(title: String(localized: "Privacy Policy"), base: "PrivacyPolicy", name: "PrivacyPolicy")
            }
        }
        #if os(iOS)
        .sheet(isPresented: $isOnboarding) {
            HelpBookView(initialChapter: "onboarding")
        }
        .sheet(isPresented: $showHelpView) {
            HelpBookView()
        }
        #endif
        .sheet(item: $songImportUrl) { url in
            NavigationStack {
                PlaylistSelectionSheet(playlists: playlists, urlToInsert: url.url)
            }
        }
        .sheet(item: $playlistImportUrl) { url in
            NavigationStack {
                ImportPlaylistSheet(url: url)
            }
        }
        .onOpenURL(perform: { url in
            print("onOpenURL: \(url)")
            let fileExtension = url.pathExtension
            
            if fileExtension.lowercased() == (UTType.playlistJSON.preferredFilenameExtension ?? "nix").lowercased() {
                playlistImportUrl = IdentifiableURL(url: url)
            } else if fileExtension.lowercased() == (UTType.songJSON.preferredFilenameExtension ?? "nix").lowercased() {
                songImportUrl = IdentifiableURL(url: url)
            }
        })
        .confirmationDialog("Create Demo Playlist?", isPresented: $showInsertDemoPlaylist) {
            Button("Create Demo Playlist", role: .confirm) {
                do {
                    try DemoHelper.createDemoPlaylist(modelContext: modelContext)
                } catch (let error) {
                    globals.setSongChordsError(error: error)
                }
            }
        }
        #if os(macOS)
        .onAppear {
            if isOnboarding {
                openWindow(id: "onboarding")
                isOnboarding = false
            }
        }
        #endif
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
        
        let plid = playlist.id
        if selectedPlaylistID == plid { selectedPlaylistID = nil }

        modelContext.delete(playlist)

        try modelContext.save()
    }
    
    private func deletePlaylists(offsets: IndexSet) throws {
        if offsets.isEmpty { return }
        
        let sortedPlaylists = playlists
        for index in offsets {
            if (sortedPlaylists[index].songs ?? []).count == 0 {
                let plid = sortedPlaylists[index].id
                if selectedPlaylistID == plid { selectedPlaylistID = nil }
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

struct ImportPlaylistSheet: View {
    let url: IdentifiableURL?
    
    @Environment(\.dismiss) private var dismiss
    @Environment(Globals.self) private var globals
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "tray.and.arrow.down.fill")
                .font(.system(size: 48))
                .foregroundStyle(.tint)

            Text("Import Playlist?")
                .font(.title2)
                .bold()

            Text("Do you want to import the selected playlist file into SongChords?")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            HStack(spacing: 16) {
                Button(role: .cancel) {
                    dismiss()
                } label: {
                    Text("Cancel")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    if let url {
                        do {
                            try importPlaylist(url: url.url)
                        } catch (let error) {
                            globals.setSongChordsError(error: error)
                        }
                    }
                    dismiss()
                } label: {
                    Text("Import")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.top, 8)
        }
        .padding(32)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
    
    private func importPlaylist(url: URL) throws {
        let playlist = try PlayListTransferable.fromUrl(url: url)
        let newPlaylist = try PlayList(modelContext: modelContext, title: playlist.title)
        modelContext.insert(newPlaylist)
        try newPlaylist.sortAndCopyCodable(songs: playlist.songs)
        try modelContext.save()
    }
}

struct PlaylistEditView: View {
    let playlist: PlayList?
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(Globals.self) private var globals

    @State private var playlistTitle: String = ""

    private enum FocusedField: Hashable {
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
                Button("Save", systemImage: "checkmark") {
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
                Button("Cancel", systemImage: "xmark") {
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

    @State private var selectedPlaylist: PlayList.ID?

    var body: some View {
        VStack {
            Text("Import into:")
            List(playlists, selection: $selectedPlaylist) { playlist in
                Text(playlist.title)
                #if os(iOS)
                    .font(.subheadline).listRowInsets(.init(top: 8, leading: 8, bottom: 8, trailing: 8))
                #endif
            }
            #if os(iOS)
            .environment(\.defaultMinListRowHeight, 20)
            #endif
            .frame(maxHeight: 350).cornerRadius(10)
            .overlay( /// apply a rounded border
                RoundedRectangle(cornerRadius: 10)
                    .stroke(.secondary, lineWidth: 1)
            )
        }
        .padding()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Done", systemImage: "checkmark") {
                    if let selectedPlaylist = selectedPlaylist {
                        if let pl = PlayList.fetchPlaylist(with: selectedPlaylist, in: modelContext) {
                            do {
                                let urlSong = try SongTransferable.fromUrl(url: urlToInsert)
                                let song = try Song(from: urlSong)
                                song.toPlaylist(playlist: pl)
                                try modelContext.save()
                            } catch (let error) {
                                globals.setSongChordsError(error: error)
                            }
                        }
                    }
                    
                    dismiss()
                }.disabled(selectedPlaylist == nil)
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", systemImage: "xmark") {
                    dismiss()
                }
            }
        }
        .navigationTitle("Import Song into Playlist")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #else
            .frame(idealHeight: 400)
        #endif
    }
}
