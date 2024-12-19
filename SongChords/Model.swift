//
//  Chord.swift
//  ChordApp
//
//  Created by Peter Wichert on 20.11.23.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

enum SongError: Error {
    case illegalSongname
}

@Model
final class PlayList: Codable {
    var seq: Int = 0
    var title: String = ""
    
    @Relationship(deleteRule: .cascade, inverse: \Song.playlist) var songs: [Song]? = [Song]()
    
    init(modelContext: ModelContext, title: String, songs: [Song] = []) {
        self.seq = nextPlaylistSeq(modelContext: modelContext)
        self.title = title.trimmingCharacters(in: .whitespaces)
        self.songs = songs
    }
    
    private func nextPlaylistSeq(modelContext: ModelContext) -> Int {
        do {
            let playlists = try modelContext.fetch(FetchDescriptor<PlayList>())
            if playlists.isEmpty { print("nextPlaylistSeq: 0"); return 0 }

            var maxSeq = 0
            for s in playlists {
                maxSeq = max(maxSeq, s.seq)
            }
            
            print("nextPlaylistSeq: \(maxSeq + 1)")
            return maxSeq + 1
        } catch {
            print("error fetching nextPlaylistSeq: \(error.localizedDescription)")
            return 0
        }
    }
    
    func nextSongSeq() -> Int {
        if (songs ?? []).isEmpty { print("nextSongSeq: 0"); return 0 }
        
        var maxSeq = 0
        if let songs = songs {
            for s in songs {
                maxSeq = max(maxSeq, s.seq)
            }
        }
        
        print("nextSongSeq: \(maxSeq+1)")
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
    
    public func sortedInsert(songs: [Song]?) {
        for song in (songs ?? []).sorted(by: { $0.seq < $1.seq }) {
            let newSong = Song(title: song.title)
            newSong.updateFromSong(other: song)
            newSong.toPlaylist(playlist: self)
        }
    }
    
    static func fetchPlaylists(with ids: Set<PlayList.ID>, in context: ModelContext) -> [PlayList] {
        if ids.isEmpty { return [] }
            
        let descriptor = FetchDescriptor<PlayList>(
            predicate: #Predicate { playlist in
                ids.contains(playlist.persistentModelID)
            }
        )
        return (try? context.fetch(descriptor)) ?? []
    }
    
    static func isValidTitle(_ playlistTitle: String) -> Bool {
        // Liste der ungültigen Zeichen für Playliste
        let invalidCharacters = CharacterSet(charactersIn: "/\\|\"")
            .union(.illegalCharacters)
            .union(.controlCharacters)
            .union(.symbols)
            .union(.newlines)
        
        // Überprüfen, ob der Dateiname leer ist oder ungültige Zeichen enthält
        if playlistTitle.trimmingCharacters(in: .whitespaces).isEmpty || playlistTitle.rangeOfCharacter(from: invalidCharacters) != nil  || playlistTitle.count > 200 {
            return false
        }
        
        return true
    }
    
    static func fromUrl(url: URL) throws -> PlayList {
        let startSecurityScope = url.startAccessingSecurityScopedResource()
        let playlistData = try Data(contentsOf: url)
        if startSecurityScope { url.stopAccessingSecurityScopedResource() }

        let decoder = JSONDecoder()
        return try decoder.decode(PlayList.self, from: playlistData)
    }
    
    enum CodingKeys: CodingKey {
//        case seq
        case title
        case songs
    }
    
    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
//        seq = try container.decode(Int.self, forKey: .seq)
        title = try container.decode(String.self, forKey: .title)
        songs = try container.decode([Song].self, forKey: .songs)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
//        try container.encode(seq, forKey: .seq)
        try container.encode(title, forKey: .title)
        try container.encode(songs, forKey: .songs)
    }
    
    @Transient var hideCodable: Bool = false
    @Transient var hidePDF: Bool = false
    func setTransCodable() -> PlayList {
        hidePDF = true
        hideCodable = false
        return self
    }
    func setTransPDF() -> PlayList {
        hideCodable = true
        hidePDF = false
        return self
    }
    func setTransAll() {
        hidePDF = false
        hideCodable = false
    }
}

extension PlayList: Transferable {
    
    // Zum Drucken: siehe unten
    
    static var transferRepresentation: some TransferRepresentation {
        // Export/Import json per AirDrop und Speichern in Datei für Playlist
        // Endung .scplaylist
        CodableRepresentation(contentType: .playlistJSON)
            .suggestedFileName { $0.title }
            .exportingCondition { playlist in
                return !playlist.hideCodable
            }

        // Export per FileDialog für PDF-Datei
        // Endung .pdf
        // uttype = .pdf
        // .fileExporter(isPresented: $showFileExport, item: song, contentTypes: [uttype], defaultFilename: playlist.title)
        FileRepresentation(exportedContentType: .pdf, exporting: { playlist in
            print("FileRepresentation (.pdf) exported playlist \(playlist.title)")
            let viewModel = ViewModel()
            let delegate = await PrintSetlistDelegate(viewModel: viewModel, playlist: playlist)
            let defaultPaper = MediaBoxes.getBox(name: viewModel.mediabox)
            guard let pdfUrl = await delegate.createPDF(paperSize: defaultPaper) else {
                throw NSError(domain: "PDFCreationError", code: 4, userInfo: ["reason": "Failed to create PDF"])
            }

            return SentTransferredFile(pdfUrl, allowAccessingOriginalFile: true)
        })
        .suggestedFileName { $0.title }
        .exportingCondition { playlist in
            return !playlist.hidePDF
        }
    }
}

extension UTType {
    static let playlistJSON = UTType(exportedAs: "com.wichert.songchordslist", conformingTo: .json)
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
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.seq = 0
    }
    
    init(title: String = "", playlist: PlayList) {
        self.title = title.trimmingCharacters(in: .whitespaces)
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
        if playlist.songs == nil { playlist.songs = [] }

        if let after = after {
            seq = after.seq
        } else {
            seq = playlist.nextSongSeq()
        }
        
        // zu neuer hinzufügen
        self.playlist = playlist
        playlist.reNumber()
    }
    
    static func fromUrl(url: URL) throws -> Song {
        let startSecurityScope = url.startAccessingSecurityScopedResource()
        let songData = try Data(contentsOf: url)
        if startSecurityScope { url.stopAccessingSecurityScopedResource() }
        return try fromData(data: songData)
    }
    
    func toUrl(url: URL) throws {
        let data = try toData()
        
        let startSecurityScope = url.startAccessingSecurityScopedResource()
        try data.write(to: url)
        if startSecurityScope { url.stopAccessingSecurityScopedResource() }
    }
    
    static func fromData(data: Data) throws -> Song {
        let decoder = JSONDecoder()
        return try decoder.decode(Song.self, from: data)
    }
    
    func toData() throws -> Data {
        let encoder = JSONEncoder()
        return try encoder.encode(self)
    }
    
    static func fromSrcText(url: URL) throws -> Song {
        let startSecurityScope = url.startAccessingSecurityScopedResource()
        let songData = try Data(contentsOf: url)
        if startSecurityScope { url.stopAccessingSecurityScopedResource() }

        let srcText = String(decoding: songData, as: UTF8.self)

        let fileName = url.deletingPathExtension().lastPathComponent
        if !Song.isValidFilename(fileName) { throw SongError.illegalSongname }
        
        let song = Song(title: fileName)
        song.srcText = srcText
        return song
    }
    
    func toTempFile(filename: String) throws -> URL {
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileURL = tempDirectory.appendingPathComponent(filename)
        print(fileURL.absoluteString)
        try toUrl(url: fileURL)
        return fileURL
    }
    
    static func findObject(song: Song, in context: ModelContext) -> Song? {
        do {
            let id = song.persistentModelID
            let pred = #Predicate<Song> { object in
                object.persistentModelID == id
            }
            
            var desc = FetchDescriptor(predicate: pred)
            desc.fetchLimit = 1
            
            let res = try context.fetch(desc)
            return res.first
        } catch {
            return nil
        }
    }
    
    static func fetchSongs(with ids: Set<Song.ID>, in context: ModelContext) -> [Song] {
        if ids.isEmpty { return [] }
            
        let descriptor = FetchDescriptor<Song>(
            predicate: #Predicate { song in
                ids.contains(song.persistentModelID)
            }
        )
        return (try? context.fetch(descriptor)) ?? []
    }
    
    static func isValidFilename(_ filename: String) -> Bool {
        // Liste der ungültigen Zeichen für Dateinamen
        let invalidCharacters = CharacterSet(charactersIn: "/\\?%*|\"<>:")
            .union(.illegalCharacters)
            .union(.controlCharacters)
            .union(.symbols)
            .union(.newlines)
        
        // Überprüfen, ob der Dateiname leer ist oder ungültige Zeichen enthält
        if filename.trimmingCharacters(in: .whitespaces).isEmpty || filename.rangeOfCharacter(from: invalidCharacters) != nil || filename.count > 200 {
            return false
        }
        
        return true
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
//        case showheader
//        case showchords
//        case showtext
//        case duration
//        case musicitemid
    }
    
    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        seq = try container.decode(Int.self, forKey: .seq)
        title = try container.decode(String.self, forKey: .title)
        srcText = try container.decode(String.self, forKey: .srctext)
        transpose = try container.decode(Int.self, forKey: .transpose)
//        showHeader = try container.decode(Bool.self, forKey: .showheader)
//        showChords = try container.decode(Bool.self, forKey: .showchords)
//        showText = try container.decode(Bool.self, forKey: .showtext)
//        duration = try container.decode(Double.self, forKey: .duration)
//        musicItemId = try container.decode(String.self, forKey: .musicitemid)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(seq, forKey: .seq)
        try container.encode(title, forKey: .title)
        try container.encode(srcText, forKey: .srctext)
        try container.encode(transpose, forKey: .transpose)
//        try container.encode(showHeader, forKey: .showheader)
//        try container.encode(showChords, forKey: .showchords)
//        try container.encode(showText, forKey: .showtext)
//        try container.encode(duration, forKey: .duration)
//        try container.encode(musicItemId, forKey: .musicitemid)
    }

    @Transient var hideCodable: Bool = false
    @Transient var hidePDF: Bool = false
    @Transient var hideData: Bool = false
    func setTransCodable() -> Song {
        hideCodable = false
        hidePDF = true
        hideData = true
        return self
    }
    func setTransData() -> Song {
        hideData = false
        hidePDF = true
        hideCodable = true
        return self
    }
    func setTransPDF() -> Song {
        hidePDF = false
        hideCodable = true
        hideData = true
        return self
    }
    func setTransAll() {
        hidePDF = false
        hideCodable = false
        hideData = false
    }
}

extension Song: Transferable {
    // Das normale Drucken funktioniert ohne exportingCondition in dieser Reihenfolge nicht (es geht nur, wenn FileRepresentation zuerst oder alleine ist).
    // HP-Drucken, in Datei speichern und AirDrop funktioniert dagegen schon.
    
    public static var transferRepresentation: some TransferRepresentation {
        // Export/Import json per AirDrop und Speichern in Datei für Song
        // Endung .songchords
        CodableRepresentation(contentType: .songJSON)
            .suggestedFileName { $0.title }
            .exportingCondition { song in
                return !song.hideCodable
            }

        // Export per FileDialog für PDF-Datei
        // Endung .pdf
        // uttype = .pdf
        // .fileExporter(isPresented: $showFileExport, item: song, contentTypes: [uttype], defaultFilename: song.title)
        FileRepresentation(exportedContentType: .pdf, exporting: { song in
            print("FileRepresentation (.pdf) exported song \(song.title)")

            do {
                let viewModel = ViewModel()
                let delegate = await PrintSongDelegate(viewModel: viewModel, song: song)
                let defaultPaper = MediaBoxes.getBox(name: viewModel.mediabox)
                guard let pdfUrl = await delegate.createPDF(paperSize: defaultPaper) else {
                    throw NSError(domain: "PDFCreationError", code: 4, userInfo: ["reason": "Failed to create PDF"])
                }
                return SentTransferredFile(pdfUrl, allowAccessingOriginalFile: true)
            } catch {
                print("Fehler beim Exportieren von PDF: \(error.localizedDescription)")
                throw error
            }
        })
        .suggestedFileName { $0.title }
        .exportingCondition { song in
            return !song.hidePDF
        }

        DataRepresentation(contentType: .songJSON, exporting: { song in
            return try song.toData()
        }
        , importing: { data in
            return try fromData(data: data)
        })
        .suggestedFileName { $0.title }
        .exportingCondition { song in
            return !song.hideData
        }

//        FileRepresentation(contentType: .songJSON, exporting: { song in
//            print("FileRepresentation (.songJSON) exported song \(song.title)")
//            guard let url = song.toTempFile(filename: song.title) else {
//                throw NSError(domain: "Transferable", code: 4, userInfo: ["reason": "Failed to create file"])
//            }
//            return SentTransferredFile(url)
//        }
//        , importing: { received in
//            print("FileRepresentation (.songJSON) imported song \(received.file.absoluteString)")
//            let song = try Song.fromUrl(url: received.file)
//            return song
//        })
//        .suggestedFileName { $0.title }
//        .exportingCondition { song in
//            return !song.hideFile
//        }

//        ProxyRepresentation(exporting: \.srcText)
//            .suggestedFileName { $0.title }
    }
}

extension UTType {
    static let songJSON = UTType(exportedAs: "com.wichert.songchords", conformingTo: .json)
}

//extension UTType {
//    public static var persistentModelID: UTType { UTType(exportedAs: "com.wichert.persistentModelID", conformingTo: .json) }
//}
//extension PersistentIdentifier: @retroactive Transferable {
//    public static var transferRepresentation: some TransferRepresentation {
//        CodableRepresentation(for: PersistentIdentifier.self, contentType: .json)
//    }
//}

