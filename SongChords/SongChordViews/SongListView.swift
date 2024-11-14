//
//  SongListView.swift
//  SongChords
//
//  Created by Peter Wichert on 07.11.24.
//

import SwiftUI
import SwiftData

struct SongListView: View {
    var playlist: PlayList  // Übergebene Playlist
    
    @Environment(\.modelContext) private var modelContext
    @Environment(ViewModel.self) private var viewModel
    
    @State private var showSongEditView: Bool = false
    @State private var deleteIndexset: IndexSet?
    @State private var showDeleteAlert: Bool = false
    @State private var showFileImport: Bool = false
    @State private var showExportToFolder: Bool = false
    @State private var contextSong: Song?

    var body: some View {
        List {
            ForEach((playlist.songs?.sorted(by: { $0.seq < $1.seq }))!) { song in
                NavigationLink(song.title, destination: SongView(song: song).environment(viewModel))
                    .contextMenu {
                        Button(action: { contextSong = song }) { Label("Move", systemImage: "arrow.uturn.left")}

                        Button(action: {
                            let sng = Song(title: song.title)
                            sng.seq = song.seq
                            sng.updateFromSong(other: song)
                            sng.toPlaylist(playlist: playlist, after: song)
                            modelContext.insert(sng)
                        }) { Label("Duplicate", systemImage: "doc.on.doc")}
                        
                        #if os(macOS)
                        Button(role: .destructive, action: {
                                let indexOfSong = (playlist.songs ?? []).sorted(by: { $0.seq < $1.seq }).firstIndex { $0 === song }
                            if let indexOfSong = indexOfSong {
                                deleteIndexset = IndexSet()
                                deleteIndexset!.insert(indexOfSong)
                                showDeleteAlert.toggle()
                            }
                        }) { Label("Delete", systemImage: "trash")}
                        #endif
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
            ToolbarItem {
                Menu("Playlist...") {
                    Button(action: {
                        importSongClipboard()
                    }) { Label("Import Clipboard", systemImage: "pencil.and.list.clipboard") }.help("Import clipboard")
                    Button(action: {
                        importSongTemplate()
                    }) { Label("New Song Template", systemImage: "doc.badge.plus") }.help("New Song Template")
                    Button(action: {
                        showFileImport.toggle()
                    }) { Label("Import Song File", systemImage: "arrow.down.doc") }.help("Import Song File")
        #if os(macOS)
                    Button(action: { exportPlaylist(playlist: playlist) }) { Label("Export playlist", systemImage: "arrow.up.doc") }.help("Export playlist")
        #else
                    Button(action: { showExportToFolder.toggle() }) { Label("Export playlist", systemImage: "arrow.up.doc") }.help("Export playlist")
        #endif
                }
            }
        }
        .sheet(isPresented: $showSongEditView) {
            NavigationStack {
                SongEditView(playlist: playlist, song: nil)
            }
            .interactiveDismissDisabled()
        }
        #if os(iOS)
        .sheet(item: $contextSong) { ctSong in
            MovePlaylistView(song: ctSong, fromPlaylist: playlist)
        }
        .sheet(isPresented: $showExportToFolder) {
            DirectoryPickerView(playlist: playlist)
        }
        #else
        .sheet(item: $contextSong) { ctSong in
            MacMovePlaylistView(song: ctSong, fromPlaylist: playlist)
        }
        #endif
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
    
    private func importSongClipboard() {
        print("Import")
        
#if os(macOS)
        let cb = NSPasteboard.general.string(forType: .string)
#else
        let cb = UIPasteboard.general.string
#endif
        
        if !(cb ?? "").isEmpty {
            let chordProReverseParser = ChordProReverseParser()
            let sections = chordProReverseParser.parse(input: cb!)
            let txt = chordProReverseParser.toString(sections: sections)
            
            let song = Song(title: "", playlist: playlist)
            modelContext.insert(song)
            song.title = "Import \(song.seq)"
            song.srcText = txt
        }
    }
    
    private func importSongTemplate() {
        let new = String(localized: "New")
        let song = Song(title: new + " " + Date.now.formatted(date: .numeric, time: .shortened))
        modelContext.insert(song)
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
    }
    
    private func importTextSong(url: URL) -> Bool {
        print("importTextSong URL: \(url.absoluteString)")
        var success = false

        let startSecurityScope = url.startAccessingSecurityScopedResource()
        
        do {
            let song = try Song.songFromText(url: url)
            let newSong = Song(title: song.title)
            modelContext.insert(newSong)
            newSong.toPlaylist(playlist: playlist)
            newSong.updateFromSong(other: song)

            success = true
        } catch {
            print(error.localizedDescription)
        }

        if startSecurityScope {
            url.stopAccessingSecurityScopedResource()
        }
        
        return success
    }
    
#if os(macOS)
    private func exportPlaylist(playlist: PlayList) {
        var dirname: String = ""
        var errtxt: String?
        
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.canChooseFiles = false
        
        if panel.runModal() == .OK {
            if let url = panel.url {
                dirname = panel.url!.path()
                print(dirname)
                
                let startSecurityScope = url.startAccessingSecurityScopedResource()

                do {
                    var cnt = 0
                    for song in playlist.songs ?? [] {
                        cnt += 1
                        let data = song.songToData()
                        let filename = song.title.count > 0 ? song.title : "title " + String(cnt)
                        var fileurl = url.appending(component: filename)
                        fileurl.appendPathExtension(for: .plainText)
                        
                        try data.write(to: fileurl, options: Data.WritingOptions.withoutOverwriting)
                    }
                } catch {
                    print("Error exporting Playlist: \(error.localizedDescription)")
                    errtxt = error.localizedDescription
                }
                
                if startSecurityScope {
                    url.stopAccessingSecurityScopedResource()
                }
            }
        }
        
        if let errtxt = errtxt {
            let alert = NSAlert()
            alert.messageText = "Aborted: " + errtxt
            _ = alert.runModal()
        }
    }
#endif
}

struct MovePlaylistView: View {
    @Environment(\.dismiss) private var dismiss

    var song: Song
    var fromPlaylist: PlayList?

    @State private var selected: PlayList?
    
    @Query(sort: \PlayList.seq, order: .forward) private var playlists: [PlayList]
        
    var body: some View {
        NavigationView {
            List(selection: $selected) {
                ForEach(playlists.filter({ $0.persistentModelID != fromPlaylist!.persistentModelID }), id: \.self) { pl in
                    Text(pl.title)
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        if let selected = selected {
                            print("---" + song.title)
                            song.toPlaylist(playlist: selected)
                        }
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
                        Text("Abort")
                    }
                }
            }.navigationTitle("Move to Playlist")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }
}

struct MacMovePlaylistView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme

    var song: Song
    var fromPlaylist: PlayList?

    @State private var selected: PlayList?
    
    @Query(sort: \PlayList.seq, order: .forward) private var playlists: [PlayList]

    var body: some View {
        Spacer()
        HStack {
            Spacer()
            Form {
                #if os(macOS)
                HStack(alignment: .center) {
                    Text("Move to Playlist").font(.subheadline).bold().foregroundStyle(Color(NSColor.labelColor)).padding(.leading, 3)
                }.padding(3)
                    .background(colorScheme == .dark ? Color.init(red: 0.1, green: 0.1, blue: 0.1) : Color.init(red: 0.9, green: 0.9, blue: 0.9))
                    .cornerRadius(5)
                #endif
                Text(" ")
                
                List(selection: $selected) {
                    ForEach(playlists.filter({ $0.persistentModelID != fromPlaylist!.persistentModelID }), id: \.self) { pl in
                        Text(pl.title)
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: {
                            if let selected = selected {
                                print("---" + song.title)
                                song.toPlaylist(playlist: selected)
                            }
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
                            Text("Abort")
                        }
                    }
                }
            }
            .frame(minWidth: 300, minHeight: 300)
            Spacer()
        }
        Spacer()
    }
}
