//
//  SongListView.swift
//  SongChords
//
//  Created by Peter Wichert on 07.11.24.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SongListView: View {
    let playlist: PlayList  // Übergebene Playlist
    @Binding var visibility: NavigationSplitViewVisibility
//    @Binding var selectedSongIDs: Set<Song.ID>
    @Binding var selectedSongs: Set<Song>
    
    @Environment(\.modelContext) private var modelContext
    @Environment(ViewModel.self) private var viewModel
    
    #if os(iOS)
    @State private var editMode: EditMode = .inactive
    #endif
    @State private var selectedSongIDs: Set<Song.ID> = []

    @State private var showSongEditView: Bool = false
    @State private var showMoveToPlaylist: Bool = false
    @State private var deleteIndexset = IndexSet()
    @State private var showDeleteAlert: Bool = false
    @State private var showFileImport: Bool = false
    @State private var showFileExport: Bool = false
    @State private var uttype: UTType = .pdf
    
    @Query private var songs: [Song]
    
    init(playlist: PlayList, visibility: Binding<NavigationSplitViewVisibility>, selectedSongs: Binding<Set<Song>>) {
        self.playlist = playlist
        self._visibility = visibility
        self._selectedSongs = selectedSongs
        
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
                        Button(action: { showMoveToPlaylist.toggle() }) { Label("Move", systemImage: "arrow.uturn.left")}

                        Button(action: {
                            print("Count: \(selectedSongs.count)")
                            for song in selectedSongs {
                                let sng = Song(title: song.title)
                                sng.seq = song.seq
                                sng.updateFromSong(other: song)
                                modelContext.insert(sng)
                                sng.toPlaylist(playlist: playlist, after: song)                                
                            }
                        }) { Label("Duplicate", systemImage: "doc.on.doc")}
                        
                        Button(role: .destructive, action: { prepareDelete() }) { Label("Delete", systemImage: "trash")}
                    }
                    #if os(macOS)
                    .draggable(try! song.toTempFile(filename: song.title)) { Text(song.title) }
//                    .draggable(song.persistentModelID) { Text(song.title) }
                    #else
                    .draggable(song.setTransData()) { Text(song.title) }
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
                Button(action: { showSongEditView.toggle() }, label: { Image(systemName: "plus.circle") })
            }
            ToolbarItem {
                Button(action: { prepareDelete() }, label: { Image(systemName: "trash")} ).help("Delete Song(s)")
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
                        // selectedSongs ist de-selektiert, wenn das .sheet started, daher vorher kopieren
                        Button(action: { showMoveToPlaylist.toggle() }) {
                            Text("Copy To").disabled(selectedSongIDs.isEmpty)
                        }
                        Spacer()
                        Text("\(String(selectedSongIDs.count)) selected").font(.footnote)
                        Spacer()
                        Button(action: { prepareDelete() }) {
                            Text("Delete").disabled(selectedSongIDs.isEmpty)
                        }
                    }
                }
            }
            ToolbarItem {//}(placement: .primaryAction) {
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
                        #if false   // kein Drucken
                        Button(action: { Task { await printSetlist() }}) { Label("Print Setlist", systemImage: "printer.dotmatrix") }.help("Print Setlist")
                        #endif
                    } label: {
                        Label("Song...", systemImage: "filemenu.and.cursorarrow")
                    }
                }
            }
            ToolbarItem {
                if !isEditing {
                    Button("Export PDF File", systemImage: "arrow.up.document.fill", action: { uttype = .pdf; playlist.setTransAll(); showFileExport.toggle() }).help("Export PDF File")
                }
            }
            #if os(macOS) // in iOS durch ShareLink ersetzt
            ToolbarItem {
                Button("Export Playlist", systemImage: "arrow.up.document", action: { uttype = .playlistJSON; playlist.setTransAll(); showFileExport.toggle() }).help("Export Playlist")
            }
            #endif
        }
        .sheet(isPresented: $showSongEditView) {
            NavigationStack {
                SongEditView(playlist: playlist, song: nil)
            }
            .interactiveDismissDisabled()
        }
        .sheet(isPresented: $showMoveToPlaylist) {
            NavigationStack {
                #if os(macOS)
                MoveToPlaylistView(songIDs: selectedSongIDs, fromPlaylist: playlist)
                #else
                MoveToPlaylistView(songIDs: selectedSongIDs, fromPlaylist: playlist, editMode: $editMode)
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
        .onChange(of: selectedSongIDs) {
            // das alles nur, weil Set<Song.ID> nicht als @Binding nach ContentView funktioniert. Daher Umweg über selectedSongs
            if selectedSongIDs.count == 1 {
                let s = Song.fetchSongs(with: selectedSongIDs, in: modelContext)
                if !s.isEmpty {
                    selectedSongs = [s.first!]
                }
            }
        }
        #if os(iOS)
        .environment(\.editMode, $editMode)
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
    
    private func prepareDelete() {
        deleteIndexset = IndexSet()
        
        let sSongs = Song.fetchSongs(with: selectedSongIDs, in: modelContext)
        
        for song in sSongs {
//            let indexOfSong = (playlist.songs ?? []).sorted(by: { $0.seq < $1.seq }).firstIndex { $0 === song }
            let indexOfSong = songs.firstIndex { $0 === song }
            if let indexOfSong = indexOfSong {
                deleteIndexset.insert(indexOfSong)
            }
        }
        
        if !deleteIndexset.isEmpty { showDeleteAlert.toggle() }
    }

    private func deleteSongs(playlist: PlayList, offsets: IndexSet) {
//        if offsets.isEmpty || (playlist.songs ?? []).count == 0 { return }
        if offsets.isEmpty || songs.count == 0 { return }

        let sortedSongs = songs // (playlist.songs ?? []).sorted(by: { $0.seq < $1.seq })
        for index in offsets {
            let s = sortedSongs[index]
            modelContext.delete(s)
            playlist.songs?.removeAll(where: { $0.seq == s.seq })
        }
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
        }
    }
    
    private func importSongTemplate() {
        let new = String(localized: "New")
        let song = Song(title: new + " " + Date.now.formatted(date: .numeric, time: .shortened))
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
    }
    
    private func importTextSong(url: URL) -> Bool {
        print("importTextSong URL: \(url.absoluteString)")
        var success = false
        
        do {
            let song = try Song.fromSrcText(url: url)
            playlist.sortedInsert(songs: [song])
            success = true
        } catch {
            print(error.localizedDescription)
        }

        return success
    }
    
    @MainActor
    func printSetlist() async {
        let delegate = PrintSetlistDelegate(viewModel: viewModel, playlist: playlist)
        PrintController.onPrint(viewModel: viewModel, title: playlist.title, delegate: delegate)
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
    @Query private var allSongs: [Song]

    var body: some View {
        List(selection: $selectedPlaylist) {
            ForEach(playlists.filter({ $0.persistentModelID != fromPlaylist.persistentModelID })) { pl in
                Text(pl.title)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    let fetchedSongs = Song.fetchSongs(with: songIDs ?? [], in: modelContext)

                    print("songs to copy: \(String(fetchedSongs.count))")
                    if let selected = selectedPlaylist {
                        if let pl = PlayList.fetchPlaylists(with: [selected], in: modelContext).first {
                            pl.sortedInsert(songs: fetchedSongs)
                        }
                    }
                    #if os(iOS)
                    editMode = .inactive
                    #endif
                    dismiss()
                }) {
                    Text("Done")
                }
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
