//
//  Chord.swift
//  ChordApp
//
//  Created by Peter Wichert on 20.11.23.
//

import SwiftUI
import SwiftData

@Model
final class PlayList {
    var seq: Int = 0
    var title: String = ""
    
    @Relationship(deleteRule: .cascade, inverse: \Song.playlist) var songs: [Song]?
    
    init(modelContext: ModelContext, title: String, songs: [Song] = []) {
        self.seq = nextPlaylistSeq(modelContext: modelContext)
        self.title = title
        self.songs = songs
    }
    
    private func nextPlaylistSeq(modelContext: ModelContext) -> Int {
        var maxSeq = -1
        
        do {
            let playlists = try modelContext.fetch(FetchDescriptor<PlayList>())
            for s in playlists.indices {
                maxSeq = max(maxSeq, playlists[s].seq)
            }
            
            print("max: \(maxSeq + 1)")
            return maxSeq + 1
        } catch {
            print("error fetching nextPlaylistSeq: \(error.localizedDescription)")
            return 0
        }
    }
    
    func nextSongSeq() -> Int {
        var maxSeq = -1
        
        if let songs = songs {
            for s in songs.indices {
                maxSeq = max(maxSeq, songs[s].seq)
            }
        }
        
        print("max: \(maxSeq + 1)")
        return maxSeq + 1
    }
    
    func reNumber() {
        guard songs != nil else { return }
        guard songs!.count > 0 else { return }
        
        let sortedSongs = songs!.sorted(by: { a, b in a.seq < b.seq })
        var newSeq = 0
        for song in sortedSongs {
            if song.seq != newSeq { song.seq = newSeq }
            newSeq += 1
        }
    }
}

class RepresentationHolder: ObservableObject {
    @Published var songRepresentation: SongRepresentation = SongRepresentation(sections: [], directiveManager: DirectiveManager())
}

@Model
final public class Song: Codable {
    var seq: Int = 0
    var title: String = ""
    var srcText: String = ""
    var musicItemId: String = ""
    var showChords: Bool = true
    var showText: Bool = true
    var showHeader: Bool = true
    var transpose: Int = 0
    var duration: Double = 200
    
    var playlist: PlayList?
    
    @Transient private(set) var representationHolder = RepresentationHolder()
    
    init(title: String = "") {
        self.title = title
        self.seq = 0
    }
    
    init(title: String = "", playlist: PlayList) {
        self.title = title
        //        self.seq = playlist.nextSongSeq()
        toPlaylist(playlist: playlist)
    }
    
    func processSongInBackground(viewModel: ViewModel, forPrinting: Bool) {
        // Eine vorherige Task abbrechen, falls eine existiert
        viewModel.processingTask?.cancel()
        
        // Neue Hintergrund-Task starten
        viewModel.processingTask = Task { [weak self] in
            // Aufgabe im Hintergrund ausführen
            guard let self = self else { return }
            let result = self.createSongRepresentation(viewModel: viewModel, forPrinting: forPrinting)
            
            // Ergebnis auf dem Main-Thread aktualisieren
            await MainActor.run {
                if let result = result {
                    self.representationHolder.songRepresentation = result
                }
            }
        }
    }
    
    func createSongRepresentation(viewModel: ViewModel, forPrinting: Bool) -> SongRepresentation? {
        do {
            print("songRepresentation")
            
            let tokens = try ChordProLexer(input: srcText).tokenize()
            if Task.isCancelled { print("cancelled"); return nil }
            
            let songRepresentation = try ChordProParser(viewModel: viewModel, songTranspose: transpose, tokens: tokens, forPrinting: forPrinting).parse()
            if Task.isCancelled { print("cancelled"); return nil }
            
            return songRepresentation
        } catch {
            print("\(error)")
            return nil
        }
    }
    
    func updateFromSong(other: Song) {
        updateFrom(title: other.title, srcText: other.srcText, transpose: other.transpose, showChords: other.showChords, showText: other.showText, showHeader: other.showHeader, duration: other.duration, musicItemId: other.musicItemId)
    }
    
    func updateFrom(title: String, srcText: String, transpose: Int, showChords: Bool, showText: Bool, showHeader: Bool, duration: Double, musicItemId: String) {
        self.title = title
        self.srcText = srcText
        self.transpose = transpose
        self.showChords = showChords
        self.showText = showText
        self.showHeader = showHeader
        self.duration = duration
        self.musicItemId = musicItemId
    }
    
    func toPlaylist(playlist: PlayList, after: Song? = nil) {
        if (playlist.songs ?? []).contains(self) { return }
        
        // aus alter Playlist entfernen
        if let myplaylist = self.playlist {
            if myplaylist.songs != nil {
                myplaylist.songs!.removeAll { $0 == self }
            }
        }
        
        // zu neuer hinzufügen
        self.playlist = playlist
        
        if playlist.songs == nil {
            playlist.songs = []
        }
        
        if let after = after {
            seq = after.seq
            let idx = playlist.songs!.firstIndex(of: after)
            if let idx = idx {
                let idxafter = playlist.songs!.index(after: idx)
                playlist.songs!.insert(self, at: idxafter)
                playlist.reNumber()
            }
        } else {
            playlist.songs!.append(self)
            seq = playlist.nextSongSeq()
            playlist.reNumber()
        }
    }
    
//    static func songFromData(url: URL) throws -> Song {
//        let songData = try Data(contentsOf: url)
//        let decoder = JSONDecoder()
//        return try decoder.decode(Song.self, from: songData)
//    }
    
    static func songFromText(url: URL) throws -> Song {
        let songData = try Data(contentsOf: url)
        let fileName = url.deletingPathExtension().lastPathComponent
        let src = String(decoding: songData, as: UTF8.self)
        let song = Song(title: fileName)
        song.srcText = src
        return song
    }
    
    func songToData() -> Data {
        return srcText.data(using: .utf8)!
    }
    
    static func findObject(modelContext: ModelContext, song: Song) -> Song? {
        do {
            let id = song.persistentModelID
            let pred = #Predicate<Song> { object in
                object.persistentModelID == id
            }
            
            var desc = FetchDescriptor(predicate: pred)
            desc.fetchLimit = 1
            
            let res = try modelContext.fetch(desc)
            return res.first
        } catch {
            return nil
        }
    }
    
    static func countSongs(modelContext: ModelContext) -> Int {
        let desc = FetchDescriptor<Song>()
        let res = (try? modelContext.fetchCount(desc)) ?? 0
        return res
    }
    
    enum CodingKeys: CodingKey {
        case seq
        case title
        case srctext
        case transpose
        case showheader
        case showchords
        case showtext
        case duration
        case musicitemid
    }
    
    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        seq = try container.decode(Int.self, forKey: .seq)
        title = try container.decode(String.self, forKey: .title)
        srcText = try container.decode(String.self, forKey: .srctext)
        transpose = try container.decode(Int.self, forKey: .transpose)
        showHeader = try container.decode(Bool.self, forKey: .showheader)
        showChords = try container.decode(Bool.self, forKey: .showchords)
        showText = try container.decode(Bool.self, forKey: .showtext)
        duration = try container.decode(Double.self, forKey: .duration)
        musicItemId = try container.decode(String.self, forKey: .musicitemid)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(seq, forKey: .seq)
        try container.encode(title, forKey: .title)
        try container.encode(srcText, forKey: .srctext)
        try container.encode(transpose, forKey: .transpose)
        try container.encode(showHeader, forKey: .showheader)
        try container.encode(showChords, forKey: .showchords)
        try container.encode(showText, forKey: .showtext)
        try container.encode(duration, forKey: .duration)
        try container.encode(musicItemId, forKey: .musicitemid)
    }
}

extension Song: Transferable {
    public static var transferRepresentation: some TransferRepresentation {
        
        FileRepresentation(exportedContentType: .pdf, exporting: { song in
            print("FileRepresentation (.pdf) exported song \(song.title)")
            let viewModel = ViewModel()
            let delegate = await PrintSongDelegate(viewModel: viewModel, song: song)
            let defaultPaper = MediaBoxes.getBox(name: viewModel.mediabox)
            let pdfUrl = await delegate.createPDF(paperSize: defaultPaper)
            return SentTransferredFile(pdfUrl!, allowAccessingOriginalFile: false)
        }).suggestedFileName { song in
            (song.title.count > 0 ? song.title : "song")
        }
        
        FileRepresentation(exportedContentType: .plainText, exporting: { song in
            print("FileRepresentation (.text) exported song \(song.title)")
            let cacheDirectoryURL =
            try FileManager.default.url(for: .cachesDirectory,
                                        in: .userDomainMask,
                                        appropriateFor: nil,
                                        create: true)
            
            let data = song.songToData()
            let filename = song.title
            let fileurl = cacheDirectoryURL.appending(component: filename)
            try data.write(to: fileurl)
            return SentTransferredFile(fileurl, allowAccessingOriginalFile: true)
        }).suggestedFileName { song in
            (song.title.count > 0 ? song.title : "song")
        }
    }
}
