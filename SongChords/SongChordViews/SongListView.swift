//
//  SongListView.swift
//  SongChords
//
//  Created by Peter Wichert on 07.11.24.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// Identifiable Wrapper für Set<PersistentIdentifier>
// für MoveToPlaylistView(), um das sheet sicher über "item:" auszulösen
struct IdentifiablePersistentIdentifierSet: Identifiable {
    let id: UUID // Eine eindeutige ID für diese Sammlung
    let identifiers: Set<PersistentIdentifier> // Die enthaltenen IDs
    
    init(identifiers: Set<PersistentIdentifier>) {
        self.id = UUID() // Eine neue eindeutige ID für jede Instanz
        self.identifiers = identifiers
    }
}

enum BgColor: Int {
    case none = 0
    case red
    case green
    case blue
    case yellow
    
    var color: Color {
        switch self {
        case .red: return Color.red
        case .green: return Color.green
        case .blue: return Color.blue
        case .yellow: return Color.yellow
        case .none: return Color.clear
        }
    }
}

struct ModifiedBG: ViewModifier {
    let color: Int
    
    func body(content: Content) -> some View {
        if let c = BgColor(rawValue: color), c != BgColor.none {
            content
            #if os(macOS)
                .listRowBackground(c.color.opacity(0.4))
            #else
                .listRowBackground(c.color.shadow(color: c.color, radius: 4).opacity(0.4))
            #endif
        } else {
            content
        }
    }
}

struct SongListView: View {
    let playlistID: PersistentIdentifier
    @Binding var visibility: NavigationSplitViewVisibility
    @Binding var selectedSongIDs: Set<PersistentIdentifier>
        
    @Query private var playlists: [PlayList]
    
    init(playlistID: PersistentIdentifier, visibility: Binding<NavigationSplitViewVisibility>, selectedSongIDs: Binding<Set<PersistentIdentifier>>) {
        self.playlistID = playlistID
        self._visibility = visibility
        self._selectedSongIDs = selectedSongIDs
                
        _playlists = Query(
            filter: #Predicate<PlayList> {
                $0.persistentModelID == playlistID
            }
        )
    }
    
    var body: some View {
        if let playlist = playlists.first {
            SongListViewX(
                playlist: playlist,
                visibility: $visibility,
                selectedSongIDs: $selectedSongIDs
            )
        } else {
            ContentUnavailableView("Select a playlist", systemImage: "doc.text.image.fill")
                .onAppear { visibility = .all }
        }
    }
}

internal struct SongListViewX: View {
    let playlist: PlayList
    @Binding var visibility: NavigationSplitViewVisibility
    @Binding var selectedSongIDs: Set<PersistentIdentifier>

    @Environment(\.modelContext) private var modelContext
    @Environment(UserSettings.self) private var userSettings
    @Environment(Globals.self) private var globals
    @Environment(AudioPlayer.self) private var audioPlayer

#if os(iOS)
    @State private var editMode: EditMode = .inactive
#endif
    
    @State private var showSongEditView: Bool = false
    @State private var songIDsToCopy: IdentifiablePersistentIdentifierSet?
    @State private var deleteIndexset = IndexSet()
    @State private var showDeleteAlert: Bool = false
    @State private var showFileImport: Bool = false
    @State private var showFileExport: Bool = false
    
    @Query private var songs: [Song]
    
    init(playlist: PlayList, visibility: Binding<NavigationSplitViewVisibility>, selectedSongIDs: Binding<Set<PersistentIdentifier>>) {
        self.playlist = playlist
        self._visibility = visibility
        self._selectedSongIDs = selectedSongIDs
        let playlistID = playlist.persistentModelID
        
        _songs = Query(
            filter: #Predicate<Song> {
                $0.playlist?.persistentModelID == playlistID
            },
            sort: \.seq, order: .forward
        )
    }
    
    var body: some View {
        List(selection: $selectedSongIDs) {
            ForEach(songs) { song in
                HStack {
                    Text(song.title)
                    if !song.musicItemId.isEmpty {
                        Spacer()
                        Image(systemName: song.musicItemId.starts(with: "local@") ? "waveform" : "music.note")
                            .foregroundStyle((song.musicItemId.starts(with: "local@") && !song.mp3FileExists()) ? .tertiary : .primary)
                    }
                }
                .modifier(ModifiedBG(color: song.backgroundColor))
                .contextMenu {
                    Menu("Highlight") {
                        Button(action: { updateBGColor(songIds: getSelectedSongIDs(song: song), color: BgColor.red) }) {
                            Text("🔴 red")
                        }
                        Button(action: { updateBGColor(songIds: getSelectedSongIDs(song: song), color: BgColor.blue) }) {
                            Text("🔵 blue")
                        }
                        Button(action: { updateBGColor(songIds: getSelectedSongIDs(song: song), color: BgColor.green) }) {
                            Text("🟢 green")
                        }
                        Button(action: { updateBGColor(songIds: getSelectedSongIDs(song: song), color: BgColor.yellow) }) {
                            Text("🟡 yellow")
                        }
                        Button(action: { updateBGColor(songIds: getSelectedSongIDs(song: song), color: BgColor.none) }) {
                            Text("⚪ none")
                        }
                    }
                    
                    Button(action: {
                        // Selektierter Song und Kontext-geklickter sind nicht unbedingt gleich.
                        songIDsToCopy = IdentifiablePersistentIdentifierSet(identifiers: selectedSongIDs.contains(song.id) ? selectedSongIDs : [song.id])
                    }) { Label("Copy To", systemImage: "arrow.uturn.left")}
                    
                    Button(action: {
                        let s = Song.fetchSongs(with: selectedSongIDs.contains(song.id) ? selectedSongIDs : [song.id], in: modelContext)
                        print("Count: \(s.count)")
                        do {
                            for song in s {
                                let sng = try Song(copying: song)
                                sng.toPlaylist(playlist: playlist, after: song)
                            }
                            try modelContext.save()
                        } catch (let error) {
                            try? modelContext.save()
                            globals.setSongChordsError(error: error)
                        }
                    }) { Label("Duplicate", systemImage: "doc.on.doc")}
                    
                    Button(role: .destructive, action: { prepareDelete(songIDs: selectedSongIDs.contains(song.id) ? selectedSongIDs : [song.id]) }) { Label("Delete", systemImage: "trash")}
                }
                // TODO: Mehrfachselektion in iOS zeigt bei drag-Beginn falsche Anzahl im Ball an
                .draggable(SongTransferable(from: song, includeCodable: true, includeData: true, autoScroll: false)) { Text(song.title) }
            }
            .onMove(perform: moveSongs)
            .onDelete { indexSet in
                deleteIndexset = indexSet
                showDeleteAlert.toggle()
            }
        }
        .navigationTitle(playlist.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .toolbar {
            #if os(macOS)
            ToolbarItem {
                Button(action: { showSongEditView.toggle() }, label: { Image(systemName: "plus.circle") }).help("New Song")
            }
            ToolbarItem {
                Button(action: { prepareDelete(songIDs: selectedSongIDs) }, label: { Image(systemName: "trash")} ).help("Delete Song(s)")
                    .disabled(selectedSongIDs.isEmpty)
            }
            #else
            if !isEditing {
                ToolbarItem(placement: .bottomBar) {
                    ShareLink (
                        item: PlayListTransferable(from: playlist, includeCodable: true), preview: SharePreview(playlist.title, image: Image("AppIconInternal"))
                    )
                }
                
                ToolbarSpacer(placement: .bottomBar)
                    
                ToolbarItem(placement: .bottomBar) {
                    Text("\(songs.count) Song").font(.footnote)
                        .fixedSize(horizontal: true, vertical: false)   // ?? sonst clipped
                }
                .sharedBackgroundVisibility(.hidden)
                
                ToolbarSpacer(placement: .bottomBar)
                
                ToolbarItem(placement: .bottomBar) {
                    Button(action: { showSongEditView.toggle() }, label: { Image(systemName: "plus.circle") })
                }
            } else {
                ToolbarItem(placement: .bottomBar) {
                    Button(action: { songIDsToCopy = IdentifiablePersistentIdentifierSet(identifiers: selectedSongIDs)
                    }) {
                        Text("Copy To")
                    }.disabled(selectedSongIDs.isEmpty)
                }
                                            
                ToolbarSpacer(placement: .bottomBar)
                    
                ToolbarItem(placement: .bottomBar) {
                    Text("\(String(selectedSongIDs.count)) selected").font(.footnote)
                        .fixedSize(horizontal: true, vertical: false)   // ?? sonst clipped
                }
                .sharedBackgroundVisibility(.hidden)

                ToolbarSpacer(placement: .bottomBar)

                ToolbarItem(placement: .bottomBar) {
                      Button(action: { prepareDelete(songIDs: selectedSongIDs) }) {
                        Text("Delete")
                    }.disabled(selectedSongIDs.isEmpty)
                }
            }
            
            ToolbarItem {
                EditButton()
            }
            #endif
                ToolbarItem {
                    if !isEditing {
                    Menu {
                        Button(action: {
                            importSongTemplate()
                        }) { Label("New Song Template", systemImage: "doc.badge.plus") }.help("New Song Template")
                        
                        Button(action: {
                            showFileImport.toggle()
                        }) { Label("Import ChordPro File", systemImage: "arrow.down.doc") }.help("Import ChordPro File")
                        
                        Button(action: {
                            importSongClipboard()
                        }) { Label("Import Text Clipboard", systemImage: "pencil.and.list.clipboard") }.help("Import Text Clipboard")
                        
                        #if os(macOS)
                        Button("Export Playlist", systemImage: "arrow.up.document", action: { showFileExport.toggle() }).help("Export Playlist")
                        #else
                        ShareLink(item: PlayListTransferable(from: playlist, includePDF: true), preview: SharePreview(playlist.title, image: Image("AppIconInternal"))) {
                            Label("Export PDF File", systemImage: "arrow.up.document.fill")
                        }
                        #endif
                        
                        #if false   // kein Drucken
                        Button(action: { Task { await printSetlist() }}) { Label("Print Setlist", systemImage: "printer.dotmatrix") }.help("Print Setlist")
                        #endif
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showSongEditView) {
            NavigationStack {
                SongEditView(playlist: playlist, song: nil)
            }
            .interactiveDismissDisabled()
        }
        .sheet(item: $songIDsToCopy) { ids in
            NavigationStack {
                #if os(macOS)
                CopyToPlaylistView(songIDs: ids.identifiers, fromPlaylist: playlist)
                #else
                CopyToPlaylistView(songIDs: ids.identifiers, fromPlaylist: playlist, editMode: $editMode)
                #endif
            }
        }
        .fileExporter(isPresented: $showFileExport, item: PlayListTransferable(from: playlist, includeCodable: true, includePDF: true), contentTypes: [], defaultFilename: Song.makeValidFilename(playlist.title)) { result in
            switch result {
            case .success(let url):
                print("Gespeichert: \(url)")
            case .failure(let error):
                globals.setSongChordsError(error: error)
            }
        }
        .fileImporter(isPresented: $showFileImport, allowedContentTypes: [.plainText], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls):
                for url in urls {
                    print("Playlist: \(playlist.title): .fileImporter: URL: " + url.absoluteString)
                    importTextSong(url: url)
                }
            case .failure(let error):
                globals.setSongChordsError(error: error)
            }
        }
        .confirmationDialog(Text("Delete \(deleteIndexset.count) Song(s)"), isPresented: $showDeleteAlert, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if !deleteIndexset.isEmpty {
                    do {
                        try deleteSongs(playlist: playlist, offsets: deleteIndexset)
                    } catch (let error) {
                        globals.setSongChordsError(error: error)
                    }
                }
            }
        }
        #if os(iOS)
        .environment(\.editMode, $editMode)
        // wenn der EditMode wechselt, soll kein Song selektiert sein
        .onChange(of: editMode) { selectedSongIDs = [] }
        #endif
    }
    
    private var isEditing: Bool {
        #if os(macOS)
        return false
        #else
        return editMode.isEditing
        #endif
    }
    
    private func updateBGColor(songIds: IdentifiablePersistentIdentifierSet, color: BgColor) {
        do {
            for ids in songIds.identifiers {
                if let s = Song.fetchSong(with: ids, in: modelContext) {
                    s.backgroundColor = color.rawValue
                }
            }
        
            try modelContext.save()
        } catch (let error) {
            globals.setSongChordsError(error: error)
        }
    }
    
    private func getSelectedSongIDs(song: Song) -> IdentifiablePersistentIdentifierSet {
        return IdentifiablePersistentIdentifierSet(identifiers: selectedSongIDs.contains(song.id) ? selectedSongIDs : [song.id])
    }
    
    private func moveSongs(from source: IndexSet, to destination: Int) {
        do {
            var sortedSongs = songs
            
            // Die Song-Reihenfolge anpassen
            sortedSongs.move(fromOffsets: source, toOffset: destination)
            
            // Die seq-Werte entsprechend der neuen Reihenfolge aktualisieren
            for index in sortedSongs.indices {
                if sortedSongs[index].seq != index { sortedSongs[index].seq = index }
            }
            
            playlist.songs = sortedSongs
            try modelContext.save()
        } catch (let error) {
            globals.setSongChordsError(error: error)
        }
    }
    
    private func prepareDelete(songIDs: Set<Song.ID>) {
        deleteIndexset = IndexSet()
        
        let sSongs = Song.fetchSongs(with: songIDs, in: modelContext)
        
        for song in sSongs {
            let indexOfSong = songs.firstIndex { $0 === song }
            if let indexOfSong = indexOfSong {
                deleteIndexset.insert(indexOfSong)
            }
        }
        
        if !deleteIndexset.isEmpty { showDeleteAlert.toggle() }
    }
    
    private func deleteSongs(playlist: PlayList, offsets: IndexSet) throws {
        if offsets.isEmpty || songs.count == 0 { return }
        
        for index in offsets {
            let s = songs[index]
            
            if s.musicItemId.starts(with: "local@") {
                s.tryRemoveMP3()
            }
            
            modelContext.delete(s)
            playlist.songs?.removeAll(where: { $0.seq == s.seq })
            selectedSongIDs.remove(s.id)
        }
        try modelContext.save()
        #if os(iOS)
        editMode = .inactive
        #endif
    }
    
    private func importSongClipboard() {
        print("Import")
        
        #if os(macOS)
        let cb = NSPasteboard.general.string(forType: .string)
        #else
        let cb = UIPasteboard.general.string
        #endif
        
        if let cb, !cb.isEmpty {
            let root: ChordRoot = userSettings.isGermanNotation ? EnglishGermanRoot() : EnglishDutchRoot()
            
            let chordProReverseParser = ChordProReverseParser(rootSystem: root)
            chordProReverseParser.parse(input: cb)
            let txt = chordProReverseParser.toString()
            
            do {
                let song = try Song(title: "Import", srcText: txt)
                song.toPlaylist(playlist: playlist)
                
                song.title = "Import \(song.seq)"
                try modelContext.save()
            } catch (let error) {
                globals.setSongChordsError(error: error)
            }
        }
    }
    
    private func importSongTemplate() {
        do {
            let song = try Song(title: String(localized: "New Song"), srcText: "")
            song.toPlaylist(playlist: playlist)
            
            song.srcText.append("{st: Subtitle of Song}\n")
            song.srcText.append("[*%{st}]\n")
            song.srcText.append("\n")
            
            song.srcText.append("[Song Section]\n")
            song.srcText.append("[Am]Lorem ipsum [D]dolor sit [E]amet\n")
            song.srcText.append("[G]consetetur [C]sadipscing elitr\n")
            
            song.srcText.append("[Another Section]\n")
            song.srcText.append("[Am]magna aliquyam [D]erat   [E]\n")
            song.srcText.append("[G]sed diam [C]voluptu\n")
            try modelContext.save()
        } catch (let error) {
            globals.setSongChordsError(error: error)
        }
    }
    
    private func importTextSong(url: URL) {
        print("importTextSong URL: \(url.absoluteString)")
        
        Task {
            do {
                let (filename, srcText) = try Song.srcTextFromText(url: url)
                let title = try await Song.titleFromDirective(srcText: srcText)
                let song = try Song(title: Song.makeValidTitle(title ?? filename), srcText: srcText)
                song.toPlaylist(playlist: playlist)
                try modelContext.save()
            } catch (let error) {
                globals.setSongChordsError(error: error)
            }
        }
    }    
}

struct CopyToPlaylistView: View {
    let songIDs: Set<Song.ID>?
    let fromPlaylist: PlayList
    #if os(iOS)
    @Binding var editMode: EditMode
    #endif
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(Globals.self) private var globals

    @State private var selectedPlaylist: PlayList.ID?
    
    @Query(sort: \PlayList.seq, order: .forward) private var playlists: [PlayList]

    var body: some View {
        VStack {
            Text("Copy to:")
            List(selection: $selectedPlaylist) {
                ForEach(playlists.filter({ $0.persistentModelID != fromPlaylist.persistentModelID })) { pl in
                    Text(pl.title)
                    #if os(iOS)
                        .font(.subheadline).listRowInsets(.init(top: 8, leading: 8, bottom: 8, trailing: 8))
                    #endif
                }
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
                Button(action: {
                    print("songs to copy: \(String((songIDs?.count ?? 0)))")
                    let fetchedSongs = Song.fetchSongs(with: songIDs ?? [], in: modelContext)

                    do {
                        if let selectedPlaylist = selectedPlaylist {
                            if let pl = PlayList.fetchPlaylist(with: selectedPlaylist, in: modelContext) {
                                try pl.sortAndCopy(songs: fetchedSongs)
                                try modelContext.save()
                            }
                        }
                    } catch (let error) {
                        try? modelContext.save()
                        globals.setSongChordsError(error: error)
                    }
                    #if os(iOS)
                    editMode = .inactive
                    #endif
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
        }.navigationTitle("Copy to Playlist")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #else
            .frame(idealHeight: 400)
        #endif
    }
}
