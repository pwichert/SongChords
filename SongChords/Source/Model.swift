//
//  Chord.swift
//  ChordApp
//
//  Created by Peter Wichert on 20.11.23.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

enum SongChordsError: Error, Equatable {
    case invalidSongtitle
    case invalidPlaylisttitle
    case playlistNotEmpty
    case limitReached

    var desc: String {
        switch self {
        case .invalidPlaylisttitle:
            return String(localized: "Invalid title")
        case .invalidSongtitle:
            return String(localized: "Invalid title")
        case .playlistNotEmpty:
            return String(localized: "Playlist must be empty")
        case .limitReached:
            return String(localized: "Free songlimit reached.\n\nEnjoying the app? Unlock song limit to manage unlimited songs and make the most out of your experience!")
        }
    }
}

@Model
final class PlayList: Codable {
    var seq: Int = 0
    var title: String = ""
    
    @Relationship(deleteRule: .cascade, inverse: \Song.playlist) var songs: [Song]? = [Song]()
    
    init(modelContext: ModelContext, title: String, songs: [Song] = []) throws {
        if !Song.isValidTitle(title) {
            throw SongChordsError.invalidPlaylisttitle
        }
        
        self.seq = try nextPlaylistSeq(modelContext: modelContext)
        self.title = title.trimmingCharacters(in: .whitespaces)
        self.songs = songs
    }
    
    private func nextPlaylistSeq(modelContext: ModelContext) throws -> Int {
        var fetchDescriptor = FetchDescriptor<PlayList>(sortBy: [ SortDescriptor(\.seq, order: .reverse) ])
        fetchDescriptor.fetchLimit = 1 // retrieve only one object

        let maxPlaylists = try modelContext.fetch(fetchDescriptor)
        
        if let maxPlaylist = maxPlaylists.first {
            print("nextPlaylistSeq: \(maxPlaylist.seq + 1)")
            return maxPlaylist.seq + 1
        } else {
            print("nextPlaylistSeq: 0")
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
    
    @MainActor
    public func sortAndCopy(songs: [Song]?, modelContext: ModelContext, store: SongChordsStore) throws {
        for song in (songs ?? []).sorted(by: { $0.seq < $1.seq }) {
            let newSong = try Song(title: song.title, modelContext: modelContext, store: store)
            newSong.updateFromSong(other: song)
            newSong.toPlaylist(playlist: self)
        }
    }
    
    static func fetchPlaylists(with ids: Set<PlayList.ID>, in context: ModelContext) -> [PlayList] {
        var res: [PlayList] = []
        
        for id in ids {
            if let playlist = fetchPlaylist(with: id, in: context) {
                res.append(playlist)
            }
        }
        
        return res
    }
    
    static func fetchPlaylist(with id: PlayList.ID, in context: ModelContext) -> PlayList? {
        return id.SCpersistentModel(from: context)
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
            .suggestedFileName { Song.makeValidFilename($0.title) }
            .exportingCondition { playlist in
                return !playlist.hideCodable
            }

        // Export per FileDialog für PDF-Datei
        // Endung .pdf
        // uttype = .pdf
        // .fileExporter(isPresented: $showFileExport, item: song, contentTypes: [uttype], defaultFilename: Song.makeValidFilename(playlist.title))
        FileRepresentation(exportedContentType: .pdf, exporting: { playlist in
            print("FileRepresentation (.pdf) exported playlist \(playlist.title)")
            let userSettings = UserSettings()
            let defaultPaper = MediaBoxes.getBox(name: userSettings.mediabox)
            let modelContainer = playlist.modelContext?.container
            guard let modelContainer else { throw NSError(domain: "PDFCreationError", code: 4, userInfo: ["reason": "Failed to create PDF"]) }
            let delegate = await PrintSetlistDelegate(playlistID: playlist.persistentModelID, modelContainer: modelContainer)
            guard let delegate = delegate, let pdfUrl = await delegate.createPDF(paperSize: defaultPaper) else {
                throw NSError(domain: "PDFCreationError", code: 4, userInfo: ["reason": "Failed to create PDF"])
            }

            return SentTransferredFile(pdfUrl, allowAccessingOriginalFile: true)
        })
        .suggestedFileName { Song.makeValidFilename($0.title) }
        .exportingCondition { playlist in
            return !playlist.hidePDF
        }
    }
}

extension UTType {
    static let playlistJSON = UTType(exportedAs: "com.wichert.songchordslist", conformingTo: .json)
}

@Observable
@MainActor
final class RepresentationHolder: Sendable {
    private(set) var songRepresentation: SongRepresentation = SongRepresentation(sections: [], directiveManager: DirectiveManagerSendable(directiveManager: DirectiveManager()))
    
    func updateSongRepresentation(_ newRepresentation: SongRepresentation) {
        songRepresentation = newRepresentation
    }
    
    // nonisolated wegen Default-Initialisierung in Song
    nonisolated init() {}
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
    var playerLoops: [PlayerLoop] = []
    
    var playlist: PlayList?
    
    @Transient let representationHolder = RepresentationHolder()
    @Transient static let invalidTitleCharacters = CharacterSet(charactersIn: "\t\\\0").union(.illegalCharacters).union(.controlCharacters).union(.newlines)
    @Transient static let invalidFilenameCharacters = CharacterSet(charactersIn: "\t\\\0/").union(.illegalCharacters).union(.symbols).union(.controlCharacters).union(.newlines)
    
    @MainActor
    init(title: String, modelContext: ModelContext, store: SongChordsStore) throws {
        if !Song.isValidTitle(title) {
            throw SongChordsError.invalidSongtitle
        }
        
        if try Song.countSongs(in: modelContext) > store.freeSongLimit && !store.unlockedSonglimit() {
            throw SongChordsError.limitReached
        }
        
        self.title = title.trimmingCharacters(in: .whitespaces)
    }

    func updateFromSong(other: Song) {
        updateFrom(title: other.title, srcText: other.srcText, transpose: other.transpose, showChords: other.showChords, showText: other.showText, showHeader: other.showHeader, duration: other.duration, musicItemId: other.musicItemId, playerLoops: other.playerLoops)
    }
    
    func updateFrom(title: String, srcText: String, transpose: Int, showChords: Bool, showText: Bool, showHeader: Bool, duration: Double, musicItemId: String, playerLoops: [PlayerLoop]) {
        self.title = title
        self.srcText = srcText
        self.transpose = transpose
        self.showChords = showChords
        self.showText = showText
        self.showHeader = showHeader
        self.duration = duration
        self.musicItemId = musicItemId
        self.playerLoops = playerLoops
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
    
    static func titleFromDirective(srcText: String) -> String? {
        do {
            let tokens = try ChordProLexer(input: srcText).tokenize()
            let songRepresentation = try ChordProParser(userSettings: UserSettings().makeSendable(), songTranspose: 0, tokens: tokens, forPrinting: false).parse()
            
            if let titleDirective = songRepresentation.directiveManager.getDirective(DirectiveType.title.rawValue) {
                return titleDirective
            }
        } catch { }
        return nil
    }
    
    func toData() throws -> Data {
        let encoder = JSONEncoder()
        return try encoder.encode(self)
    }
    
    static func srcTextFromText(url: URL, modelContext: ModelContext) throws -> (title: String, srcText: String) {
        let startSecurityScope = url.startAccessingSecurityScopedResource()
        let songData = try Data(contentsOf: url)
        if startSecurityScope { url.stopAccessingSecurityScopedResource() }

        let srcText = String(decoding: songData, as: UTF8.self)
        let fileName = url.deletingPathExtension().lastPathComponent
        
        return (fileName, srcText)
    }
    
    func toTempFile(filename: String) throws -> URL {
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileURL = tempDirectory.appendingPathComponent(filename)
        print(fileURL.absoluteString)
        try toUrl(url: fileURL)
        return fileURL
    }
    
    static func fetchSongs(with ids: Set<PersistentIdentifier>, in context: ModelContext) -> [Song] {
        var res: [Song] = []
        
        for id in ids {
            if let song = fetchSong(with: id, in: context) {
                res.append(song)
            }
        }
        
        return res
    }
    
    static func fetchSong(with id: PersistentIdentifier, in context: ModelContext) -> Song? {
        return id.SCpersistentModel(from: context)
    }

    static func fetchSongProcessing(with id: PersistentIdentifier, in context: ModelContext, userSettings: UserSettingsSendable, forPrinting: Bool) -> Song? {
        let song = Song.fetchSong(with: id, in: context)

        if let song {
            let representationHolder = song.representationHolder
            let srcText = song.srcText
            let transpose = song.transpose
            
            Task {
                await SongTaskManager.shared.processSongInBackground(representationHolder: representationHolder, srcText: srcText, transpose: transpose, userSettings: userSettings)
            }
        }
        
        return song
    }

    static func isValidTitle(_ title: String) -> Bool {
        // Überprüfen, ob der title leer ist oder ungültige Zeichen enthält
        if title.trimmingCharacters(in: .whitespaces).isEmpty || title.rangeOfCharacter(from: invalidTitleCharacters) != nil || title.count > 300 {
            return false
        }
        
        return true
    }

    static func isValidFilename(_ title: String) -> Bool {
        // Überprüfen, ob der title leer ist oder ungültige Zeichen enthält
        if title.trimmingCharacters(in: .whitespaces).isEmpty || title.rangeOfCharacter(from: invalidFilenameCharacters) != nil || title.count > 300 {
            return false
        }
        
        return true
    }

    static func makeValidTitle(_ title: String) -> String {
        return title.components(separatedBy: invalidTitleCharacters).joined(separator: "_")
    }
    
    static func makeValidFilename(_ title: String) -> String {
        return title.components(separatedBy: invalidFilenameCharacters).joined(separator: "_")
    }
    
    static func countSongs(in modelContext: ModelContext) throws -> Int {
        let desc = FetchDescriptor<Song>()
        return try modelContext.fetchCount(desc)
    }
    
    enum CodingKeys: CodingKey {
        case seq
        case title
        case srctext
        case transpose
//        case showheader
//        case showchords
        case showtext
//        case duration
        case musicitemid
        case playerloops
    }
    
    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        seq = try container.decode(Int.self, forKey: .seq)
        title = try container.decode(String.self, forKey: .title)
        srcText = try container.decode(String.self, forKey: .srctext)
        transpose = try container.decode(Int.self, forKey: .transpose)
//        showHeader = try container.decode(Bool.self, forKey: .showheader)
//        showChords = try container.decode(Bool.self, forKey: .showchords)
//        duration = try container.decode(Double.self, forKey: .duration)
        if container.contains(.musicitemid) { musicItemId = try container.decode(String.self, forKey: .musicitemid) } else { musicItemId = "" }
        if container.contains(.playerloops) { playerLoops = try container.decode([PlayerLoop].self, forKey: .playerloops) } else { playerLoops = [] }
        if container.contains(.showtext) { showText = try container.decode(Bool.self, forKey: .showtext) }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(seq, forKey: .seq)
        try container.encode(title, forKey: .title)
        try container.encode(srcText, forKey: .srctext)
        try container.encode(transpose, forKey: .transpose)
//        try container.encode(showHeader, forKey: .showheader)
//        try container.encode(showChords, forKey: .showchords)
        try container.encode(showText, forKey: .showtext)
//        try container.encode(duration, forKey: .duration)
        try container.encode(musicItemId, forKey: .musicitemid)
        try container.encode(playerLoops, forKey: .playerloops)
    }

    @Transient var hideCodable: Bool = false
    @Transient var hidePDF: Bool = false
    @Transient var hideData: Bool = false
    @Transient var hideFile: Bool = false
    func setTransCodable() -> Song {
        hideCodable = false
        hidePDF = true
        hideData = true
        hideFile = true
        return self
    }
    func setTransData() -> Song {
        hideData = false
        hidePDF = true
        hideCodable = true
        hideFile = true
        return self
    }
//    func setTransFile() -> Song {
//        hideFile = false
//        hideCodable = true
//        hideData = true
//        hidePDF = true
//        return self
//    }
    func setTransPDF() -> Song {
        hidePDF = false
        hideCodable = true
        hideData = true
        hideFile = true
        return self
    }
    func setTransAll() {
        hidePDF = false
        hideCodable = false
        hideData = false
        hideFile = true
    }
}

extension Song: Transferable {
    // Das normale Drucken funktioniert ohne exportingCondition in dieser Reihenfolge nicht (es geht nur, wenn FileRepresentation zuerst oder alleine ist).
    // HP-Drucken, in Datei speichern und AirDrop funktioniert dagegen schon.
    
    public static var transferRepresentation: some TransferRepresentation {
        // Export/Import json per AirDrop und Speichern in Datei für Song
        // Endung .songchords
        CodableRepresentation(contentType: .songJSON)
            .suggestedFileName { Song.makeValidFilename($0.title) }
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
                let userSettings = UserSettings()
                let defaultPaper = MediaBoxes.getBox(name: userSettings.mediabox)
                let modelContainer = song.modelContext?.container
                guard let modelContainer else { throw NSError(domain: "PDFCreationError", code: 4, userInfo: ["reason": "Failed to create PDF"]) }
                let delegate = await PrintSongDelegate(songID: song.persistentModelID, modelContainer: modelContainer)
                guard let delegate = delegate, let pdfUrl = await delegate.createPDF(paperSize: defaultPaper) else {
                    throw NSError(domain: "PDFCreationError", code: 4, userInfo: ["reason": "Failed to create PDF"])
                }
                let url1 = pdfUrl.deletingLastPathComponent()
                let url2 = url1.appendingPathComponent(Song.makeValidFilename(song.title) + ".pdf")
                if FileManager.default.fileExists(atPath: url2.path) {
                    try FileManager.default.removeItem(at: url2)
                }
                try FileManager.default.copyItem(at: pdfUrl, to: url2)
                return SentTransferredFile(url2, allowAccessingOriginalFile: true)
            } catch {
                print("Fehler beim Exportieren von PDF: \(error.localizedDescription)")
                throw error
            }
        })
        .suggestedFileName { Song.makeValidFilename($0.title) }
        .exportingCondition { song in
            return !song.hidePDF
        }

        DataRepresentation(contentType: .songJSON, exporting: { song in
            return try song.toData()
        }
        , importing: { data in
            return try fromData(data: data)
        })
        .suggestedFileName { Song.makeValidFilename($0.title) }
        .exportingCondition { song in
            return !song.hideData
        }

//        FileRepresentation(contentType: .songJSON, exporting: { song in
//            print("FileRepresentation (.songJSON) exported song \(song.title)")
//            guard let url = song.toTempFile(filename: Song.makeValidFilename(song.title)) else {
//                throw NSError(domain: "Transferable", code: 4, userInfo: ["reason": "Failed to create file"])
//            }
//            return SentTransferredFile(url)
//        }
//        , importing: { received in
//            print("FileRepresentation (.songJSON) imported song \(received.file.absoluteString)")
//            let song = try Song.fromUrl(url: received.file)
//            return song
//        })
//        .suggestedFileName { Song.makeValidFilename($0.title) }
//        .exportingCondition { song in
//            return !song.hideFile
//        }

//        ProxyRepresentation(exporting: \.srcText)
//            .suggestedFileName { Song.makeValidFilename($0.title) }
    }
}

extension UTType {
    static let songJSON = UTType(exportedAs: "com.wichert.songchords", conformingTo: .json)
}

extension PersistentIdentifier {
    public func SCpersistentModel<Model>(from context: ModelContext) -> Model? where Model : PersistentModel {
        return context.model(for: self) as? Model
    }
}

extension PersistentIdentifier {
    public func SCtoString() throws -> String? {
        let jsonData = try JSONEncoder().encode(self)
        return String(data: jsonData, encoding: .utf8)
    }
    
    public static func SCfromString(_ string: String) throws -> PersistentIdentifier? {
        guard let jsonData = string.data(using: .utf8) else { return nil }
        return try JSONDecoder().decode(PersistentIdentifier.self, from: jsonData)
    }
}
