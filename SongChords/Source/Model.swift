//
//  Chord.swift
//  ChordApp
//
//  Created by Peter Wichert on 20.11.23.
//

import SwiftUI
import SwiftData

enum SongChordsError: Error, Equatable {
    case invalidSongtitle
    case invalidPlaylisttitle
    case playlistNotEmpty
    case limitReached
    case invalidMP3reference

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
        case .invalidMP3reference:
            return String(localized: "Invalid file reference")
        }
    }
}

@Model
final class PlayList: Identifiable {
    var seq: Int = 0
    var title: String = ""
    
    @Relationship(deleteRule: .cascade, inverse: \Song.playlist) var songs: [Song]? = [Song]()
    
    init(modelContext: ModelContext, title: String, songs: [Song] = []) throws {
        if !Song.isValidTitle(title) {
            throw SongChordsError.invalidPlaylisttitle
        }
        
        self.title = title.trimmingCharacters(in: .whitespaces)
        self.songs = songs
        self.seq = try nextPlaylistSeq(modelContext: modelContext)
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
            let newSong = try Song(copying: song, modelContext: modelContext, store: store)

            // MP3 nicht kopieren, da sonst mehrere Songs auf das gleiche MP3 zeigen.
            // Wenn dann davon eine inkl. MP3 glöscht würde, wäre das MP3 auch für die anderen weg.
            // Also: beim Song-Kopieren wird MP3 nicht mitkopiert, sondern muss neu zugeordnet werden.
            if newSong.musicItemId.starts(with: "local@") { newSong.musicItemId = "" }

            newSong.toPlaylist(playlist: self)
        }
    }
    
    @MainActor
    public func sortAndCopyCodable(songs: [SongTransferable]?, modelContext: ModelContext, store: SongChordsStore) throws {
        for song in (songs ?? []).sorted(by: { $0.seq < $1.seq }) {
            let newSong = try Song(from: song, modelContext: modelContext, store: store)

            // MP3 nicht kopieren, da sonst mehrere Songs auf das gleiche MP3 zeigen.
            // Wenn dann davon eine inkl. MP3 glöscht würde, wäre das MP3 auch für die anderen weg.
            // Also: beim Song-Kopieren wird MP3 nicht mitkopiert, sondern muss neu zugeordnet werden.
            if newSong.musicItemId.starts(with: "local@") { newSong.musicItemId = "" }

            newSong.toPlaylist(playlist: self)
        }
    }
    
    @MainActor
    static func fetchPlaylists(with ids: Set<PlayList.ID>, in context: ModelContext) -> [PlayList] {
        var res: [PlayList] = []
        
        for id in ids {
            if let playlist = fetchPlaylist(with: id, in: context) {
                res.append(playlist)
            }
        }
        
        return res
    }
    
    @MainActor
    static func fetchPlaylist(with id: PlayList.ID, in context: ModelContext) -> PlayList? {
        return id.SCpersistentModel(from: context)
    }
}



@Observable
final class RepresentationHolder: Sendable {
    private(set) var songRepresentation: SongRepresentation = SongRepresentation(sections: [], directiveManager: DirectiveManagerSendable(directiveManager: DirectiveManager()))
    
    func updateSongRepresentation(_ newRepresentation: SongRepresentation) {
        songRepresentation = newRepresentation
    }
    
    // nonisolated wegen Default-Initialisierung in Song
    nonisolated init() {}
}

@Model
final public class Song: Identifiable {
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
    var backgroundColor: Int = 0

    var playlist: PlayList?
    
    @Transient let representationHolder = RepresentationHolder()
    @Transient static let invalidTitleCharacters = CharacterSet(charactersIn: "\t\\\0").union(.illegalCharacters).union(.controlCharacters).union(.newlines)
    @Transient static let invalidFilenameCharacters = CharacterSet(charactersIn: "\t\\\0/").union(.illegalCharacters).union(.symbols).union(.controlCharacters).union(.newlines)
        
    @MainActor
    init(title: String, srcText: String, transpose: Int = 0, showChords: Bool = true, showText: Bool = true, showHeader: Bool = true, duration: Double = 200, musicItemId: String = "", playerLoops: [PlayerLoop] = [], backgroundColor: Int = 0, modelContext: ModelContext, store: SongChordsStore) throws {
        if !Song.isValidTitle(title) {
            throw SongChordsError.invalidSongtitle
        }
        
        if try Song.countSongs(in: modelContext) > store.freeSongLimit && !store.unlockedSonglimit() {
            throw SongChordsError.limitReached
        }
        
        self.title = title.trimmingCharacters(in: .whitespaces)
        self.srcText = srcText
        self.transpose = transpose
        self.showChords = showChords
        self.showText = showText
        self.showHeader = showHeader
        self.duration = duration
        self.musicItemId = musicItemId
        self.playerLoops = playerLoops
        self.backgroundColor = backgroundColor
    }

    @MainActor
    convenience init(copying other: Song, modelContext: ModelContext, store: SongChordsStore) throws {
        try self.init(title: other.title, srcText: other.srcText, transpose: other.transpose, showChords: other.showChords, showText: other.showText, showHeader: other.showHeader, duration: other.duration, musicItemId: other.musicItemId, playerLoops: other.playerLoops, backgroundColor: other.backgroundColor, modelContext: modelContext, store: store)
    }
    
    @MainActor
    convenience init(from snapshot: SongTransferable, modelContext: ModelContext, store: SongChordsStore) throws {
        try self.init(title: snapshot.title, srcText: snapshot.srcText, transpose: snapshot.transpose, showChords: snapshot.showChords, showText: snapshot.showText, showHeader: snapshot.showHeader, duration: snapshot.duration, musicItemId: snapshot.musicItemId, playerLoops: snapshot.playerLoops, backgroundColor: snapshot.backgroundColor, modelContext: modelContext, store: store)
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

    @MainActor
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
        
    static func srcTextFromText(url: URL, modelContext: ModelContext) throws -> (title: String, srcText: String) {
        let startSecurityScope = url.startAccessingSecurityScopedResource()
        let songData = try Data(contentsOf: url)
        if startSecurityScope { url.stopAccessingSecurityScopedResource() }

        let srcText = String(decoding: songData, as: UTF8.self)
        let fileName = url.deletingPathExtension().lastPathComponent
        
        return (fileName, srcText)
    }
    
    @MainActor
    static func fetchSongs(with ids: Set<PersistentIdentifier>, in context: ModelContext) -> [Song] {
        var res: [Song] = []
        
        for id in ids {
            if let song = fetchSong(with: id, in: context) {
                res.append(song)
            }
        }
        
        return res
    }
    
    nonisolated
    static func fetchSong(with id: PersistentIdentifier, in context: ModelContext) -> Song? {
        return id.SCpersistentModel(from: context)
    }

    @MainActor
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
    
    func getMP3Info() throws -> (url: String, pitch: Float) {        
        let substr = musicItemId.split(separator: "@", omittingEmptySubsequences: false)
        if substr.count != 3 || substr[0] != "local" || substr[1].isEmpty || substr[2].isEmpty {
            throw SongChordsError.invalidMP3reference
        }
        
        let pitch = Float(substr[2]) ?? 0.0
        return (String(substr[1]), pitch)
    }
    
    func getMP3FileInfo() -> String? {
        do {
            let (url, _) = try getMP3Info()
            return url
        } catch {}
       
        return nil
    }
    
    func setMP3Info(uuid: String, pitch: Float) {
        musicItemId = "local@\(uuid)@" + String(format: "%.2f", pitch)
    }
    
    @MainActor
    func mp3FileExists() -> Bool {
        do {
            let destDir = try GlobalFunctions.mp3Path()
            let (sUuid, _) = try getMP3Info()
            let destURL = destDir
                .appendingPathComponent(sUuid + ".mp3")
        
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: destURL.path) { return true }
        } catch { }
        return false
    }
    
    @MainActor
    func tryRemoveMP3() {
        do {
            let destDir = try GlobalFunctions.mp3Path()
            let (sUuid, _) = try getMP3Info()
            let destURL = destDir
                .appendingPathComponent(sUuid + ".mp3")
        
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: destURL.path) {
                try fileManager.removeItem(at: destURL)
            }
        } catch {}
    }
}

extension PersistentIdentifier {
    nonisolated public func SCpersistentModel<Model>(from context: ModelContext) -> Model? where Model : PersistentModel {
        return context.model(for: self) as? Model
    }
}
