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

struct SongListView: View {
    let playlist: PlayList  // Übergebene Playlist
    @Binding var visibility: NavigationSplitViewVisibility
    @Binding var selectedSongIDs: Set<PersistentIdentifier>

    @Environment(\.modelContext) private var modelContext
    @Environment(ViewModel.self) private var viewModel
    
#if os(iOS)
    @State private var editMode: EditMode = .inactive
#endif
    
    @State private var showSongEditView: Bool = false
    @State private var songIDsToCopy: IdentifiablePersistentIdentifierSet?
    @State private var deleteIndexset = IndexSet()
    @State private var showDeleteAlert: Bool = false
    @State private var showFileImport: Bool = false
    @State private var showFileExport: Bool = false
    @State private var uttype: UTType = .pdf
    
    @Query private var songs: [Song]
    
    init(playlist: PlayList, visibility: Binding<NavigationSplitViewVisibility>, selectedSongIDs: Binding<Set<PersistentIdentifier>>) {
        self.playlist = playlist
        self._visibility = visibility
        self._selectedSongIDs = selectedSongIDs
        
        let id = playlist.persistentModelID
        let pred = #Predicate<Song> { song in
            song.playlist?.persistentModelID == id
        }
            
        _songs = Query(filter: pred, sort: \.seq, order: .forward)
    }
    
    var body: some View {
        List(selection: $selectedSongIDs) {
            ForEach(songs) { song in
                Text(song.title)
                    .contextMenu {
                        Button(action: {
                            // Selektierter Song und Kontext-geklickter sind nicht unbedingt gleich.
                            songIDsToCopy = IdentifiablePersistentIdentifierSet(identifiers: selectedSongIDs.contains(song.id) ? selectedSongIDs : [song.id])
                        }) { Label("Copy To", systemImage: "arrow.uturn.left")}
                        
                        Button(action: {
                            let s = Song.fetchSongs(with: selectedSongIDs.contains(song.id) ? selectedSongIDs : [song.id], in: modelContext)
                            print("Count: \(s.count)")
                            for song in s {
                                let sng = Song(title: song.title)
                                sng.updateFromSong(other: song)
                                sng.toPlaylist(playlist: playlist, after: song)
                            }
                            try? modelContext.save()
                        }) { Label("Duplicate", systemImage: "doc.on.doc")}
                        
                        Button(role: .destructive, action: { prepareDelete(songIDs: selectedSongIDs.contains(song.id) ? selectedSongIDs : [song.id]) }) { Label("Delete", systemImage: "trash")}
                    }
                #if DEBUG
                    #if os(iOS)
                    // TODO: zählt in drag-Gesten-Bubble nicht alle selektierten Songs. Ohne draggable wird richtig gezählt.
                    .draggable(song.setTransData()) { Text(song.title) }
                    #else
                    // TODO: funktioniert nur mit Typen, die bereits Transferable sind (String, URL).
                    // URL ist wegen möglicher gleicher Dateinamen (= Song.title) nicht zu verwenden.
                    // String der persistentModelID funktioniert zwar innerhalb der App, kann aber sinnloserweise ins System gedropped werden.
                    .draggable(song.persistentModelID.SCtoString()) { Text(song.title) }
                    #endif
                #endif
            }
            .onMove(perform: moveSongs)
            .onDelete { indexSet in
                deleteIndexset = indexSet
                showDeleteAlert.toggle()
            }
        }
        .navigationTitle(playlist.title)
        .toolbar {
            #if os(macOS)
            ToolbarItem {
                Button(action: { songIDsToCopy = IdentifiablePersistentIdentifierSet(identifiers: selectedSongIDs) }, label: { Image(systemName: "plus.circle") })
            }
            ToolbarItem {
                Button(action: { prepareDelete(songIDs: selectedSongIDs) }, label: { Image(systemName: "trash")} ).help("Delete Song(s)")
            }
            #else
            ToolbarItem(placement: .bottomBar) { // Fügt Menü unten hinzu
                if !isEditing {
                    HStack {
                        ShareLink (
                            item: playlist.setTransCodable(), preview: SharePreview(Text(playlist.title), image: Image("AppIconInternal"))
                        )
                        Spacer()
                        Text("\(songs.count) Song").font(.footnote)
                        Spacer()
                        Button(action: { showSongEditView.toggle() }, label: { Image(systemName: "plus.circle") })
                    }
                } else {
                    HStack {
                        Button(action: { songIDsToCopy = IdentifiablePersistentIdentifierSet(identifiers: selectedSongIDs)
                        }) {
                            Text("Copy To").disabled(selectedSongIDs.isEmpty)
                        }
                        Spacer()
                        Text("\(String(selectedSongIDs.count)) selected").font(.footnote)
                        Spacer()
                        Button(action: { prepareDelete(songIDs: selectedSongIDs) }) {
                            Text("Delete").disabled(selectedSongIDs.isEmpty)
                        }
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
                        Button(action: {
                            importSongTemplate()
                        }) { Label("New Song Template", systemImage: "doc.badge.plus") }.help("New Song Template")
                        
                        Button(action: {
                            showFileImport.toggle()
                        }) { Label("Import ChordPro File", systemImage: "arrow.down.doc") }.help("Import ChordPro File")
                        
                        Button(action: {
                            importSongClipboard()
                        }) { Label("Import Text Clipboard", systemImage: "pencil.and.list.clipboard") }.help("Import Text Clipboard")
                        
                        Button("Export PDF File", systemImage: "arrow.up.document.fill", action: { uttype = .pdf; playlist.setTransAll(); showFileExport.toggle() }).help("Export PDF File")
                        
                        #if os(macOS) // in iOS durch ShareLink ersetzt
                        Button("Export Playlist", systemImage: "arrow.up.document", action: { uttype = .playlistJSON; playlist.setTransAll(); showFileExport.toggle() }).help("Export Playlist")
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
                MoveToPlaylistView(songIDs: ids.identifiers, fromPlaylist: playlist)
            #else
                MoveToPlaylistView(songIDs: ids.identifiers, fromPlaylist: playlist, editMode: $editMode)
            #endif
            }
        }
        .fileExporter(isPresented: $showFileExport, item: playlist, contentTypes: [uttype], defaultFilename: playlist.title) { result in
            switch result {
            case .success(let url):
                print("Gespeichert: \(url)")
            case .failure(let error):
                print("Fehler: \(error.localizedDescription)")
            }
        }
        .fileImporter(isPresented: $showFileImport, allowedContentTypes: [.plainText], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls):
                for url in urls {
                    print("Playlist: \(playlist.title): .fileImporter: URL: " + url.absoluteString)
                    let success = importTextSong(url: url)
                    if !success { break }
                }
            case .failure(let error):
                print("Playlist: \(playlist.title): .fileImporter: " + error.localizedDescription)
            }
        }
        .confirmationDialog(Text("Delete \(deleteIndexset.count) Song(s)"), isPresented: $showDeleteAlert, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if !deleteIndexset.isEmpty {
                    deleteSongs(playlist: playlist, offsets: deleteIndexset)
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
    
    private func moveSongs(from source: IndexSet, to destination: Int) {
        var sortedSongs = songs
        
        // Die Song-Reihenfolge anpassen
        sortedSongs.move(fromOffsets: source, toOffset: destination)
        
        // Die seq-Werte entsprechend der neuen Reihenfolge aktualisieren
        for index in sortedSongs.indices {
            if sortedSongs[index].seq != index { sortedSongs[index].seq = index }
        }
        
        playlist.songs = sortedSongs
        #if os(iOS)
        editMode = .inactive
        #endif
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
    
    private func deleteSongs(playlist: PlayList, offsets: IndexSet) {
        if offsets.isEmpty || songs.count == 0 { return }
        
        for index in offsets {
            let s = songs[index]
            modelContext.delete(s)
            playlist.songs?.removeAll(where: { $0.seq == s.seq })
        }
        try? modelContext.save()
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
        
        if !(cb ?? "").isEmpty {
            let chordProReverseParser = ChordProReverseParser()
            
            var root: ChordRoot = viewModel.isGermanNotation ? EnglishGermanRoot() : EnglishDutchRoot()
            
            let sections = chordProReverseParser.parse(input: cb!, rootSystem: &root)
            let txt = chordProReverseParser.toString(sections: sections)
            
            let song = Song(title: "", playlist: playlist)
            song.title = "Import \(song.seq)"
            song.srcText = txt
            playlist.sortedInsert(songs: [song])
            try? modelContext.save()
        }
    }
    
    private func importSongTemplate() {
        let song = Song(title: String(localized: "New Song"))
        playlist.sortedInsert(songs: [song])

        song.srcText.append("{st: Subtitle of Song}\n")
        song.srcText.append("[*%{st}]\n")
        song.srcText.append("\n")
        
        song.srcText.append("[Song Section]\n")
        song.srcText.append("[Am]Lorem ipsum [D]dolor sit [E]amet\n")
        song.srcText.append("[G]consetetur [C]sadipscing elitr\n")
        
        song.srcText.append("[Another Section]\n")
        song.srcText.append("[Am]magna aliquyam [D]erat   [E]\n")
        song.srcText.append("[G]sed diam [C]voluptu\n")
        try? modelContext.save()
    }
    
    private func importTextSong(url: URL) -> Bool {
        print("importTextSong URL: \(url.absoluteString)")
        var success = false
        
        do {
            let song = try Song.fromSrcText(url: url)
            playlist.sortedInsert(songs: [song])
            try? modelContext.save()
            success = true
        } catch {
            print(error.localizedDescription)
        }
        
        return success
    }
    
    @MainActor
    func printSetlist() async {
        let modelContainer = modelContext.container
        if let delegate = PrintSetlistDelegate(playlistID: playlist.persistentModelID, modelContainer: modelContainer) {
            PrintController.onPrint(title: playlist.title, delegate: delegate)
        }
    }
}

struct MoveToPlaylistView: View {
    let songIDs: Set<Song.ID>?
    let fromPlaylist: PlayList
    #if os(iOS)
    @Binding var editMode: EditMode
    #endif
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPlaylist: PlayList.ID?
    
    @Query(sort: \PlayList.seq, order: .forward) private var playlists: [PlayList]

    var body: some View {
        List(selection: $selectedPlaylist) {
            ForEach(playlists.filter({ $0.persistentModelID != fromPlaylist.persistentModelID })) { pl in
                Text(pl.title)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    print("songs to copy: \(String((songIDs?.count ?? 0)))")
                    let fetchedSongs = Song.fetchSongs(with: songIDs ?? [], in: modelContext)

                    if let selectedPlaylist = selectedPlaylist {
                        if let pl = PlayList.fetchPlaylist(with: selectedPlaylist, in: modelContext) {
                            pl.sortedInsert(songs: fetchedSongs)
                            try? modelContext.save()
                        }
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
