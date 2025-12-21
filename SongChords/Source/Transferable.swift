//
//  Transferable.swift
//  SongChords
//
//  Created by Peter Wichert on 01.12.25.
//

import Foundation
import SwiftUI
import SwiftData
import UniformTypeIdentifiers

extension UTType {
    nonisolated
    static let songJSON = UTType(exportedAs: "com.wichert.songchords", conformingTo: .json)
}

extension UTType {
    nonisolated
    static let playlistJSON = UTType(exportedAs: "com.wichert.songchordslist", conformingTo: .json)
}

struct PlayListTransferable: Transferable, Codable, Identifiable {
    let persistentId: PersistentIdentifier?
    internal let id = UUID()
    let seq: Int
    let title: String
    let songs: [SongTransferable]

    let includeCodable: Bool
    let includeData: Bool
    let includePDF: Bool

    enum CodingKeys: CodingKey {
        case seq
        case title
        case songs
    }
    
    init(from playlist: PlayList, includeCodable: Bool = false, includeData: Bool = false, includePDF: Bool = false) {
        self.includeCodable = includeCodable
        self.includeData = includeData
        self.includePDF = includePDF

        self.persistentId = playlist.id
        self.seq = playlist.seq
        self.title = playlist.title
        self.songs = (playlist.songs ?? []).compactMap { SongTransferable(from: $0, includeCodable: includeCodable, includeData: includeData, includePDF: includePDF) }
    }
    
    public init(from decoder: Decoder) throws {
        self.includeCodable = false
        self.includeData = false
        self.includePDF = false

        self.persistentId = nil
        let container = try decoder.container(keyedBy: CodingKeys.self)
        seq = try container.decode(Int.self, forKey: .seq)
        title = try container.decode(String.self, forKey: .title)
        songs = try container.decode([SongTransferable].self, forKey: .songs)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(seq, forKey: .seq)
        try container.encode(title, forKey: .title)
        try container.encode(songs, forKey: .songs)
    }
    
    static func fromUrl(url: URL) throws -> PlayListTransferable {
        let startSecurityScope = url.startAccessingSecurityScopedResource()
        let playlistData = try Data(contentsOf: url)
        if startSecurityScope { url.stopAccessingSecurityScopedResource() }

        let decoder = JSONDecoder()
        return try decoder.decode(PlayListTransferable.self, from: playlistData)
    }
    
    func toTempFile(filename: String) throws -> URL {
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileURL = tempDirectory.appendingPathComponent(filename)
        print(fileURL.absoluteString)
        try toUrl(url: fileURL)
        return fileURL
    }
    
    func toUrl(url: URL) throws {
        let data = try toData()
        
        let startSecurityScope = url.startAccessingSecurityScopedResource()
        try data.write(to: url)
        if startSecurityScope { url.stopAccessingSecurityScopedResource() }
    }
    
    func toData() throws -> Data {
        let encoder = JSONEncoder()
        return try encoder.encode(self)
    }

    public static var transferRepresentation: some TransferRepresentation {
        // Endung .scplaylist
        CodableRepresentation(contentType: .playlistJSON)
        .suggestedFileName { Song.makeValidFilename($0.title) }
        .exportingCondition { playlist in return playlist.includeCodable }

        // Nur für DragDrop auf außerhalb
        DataRepresentation(exportedContentType: .fileURL, exporting: { playlist in
            let url = try playlist.toTempFile(filename: "\(Song.makeValidFilename(playlist.title)).scplaylist")
            return url.dataRepresentation
        })
        .exportingCondition { playlist in return playlist.includeData } // soll beim File-Exporter nicht erscheinen
        
        // für fileExporter-Auswahl
        DataRepresentation(exportedContentType: .pdf) { playlistPDF in
            let PDFrep = PDFHelper()
            
            guard let id = playlistPDF.persistentId else { throw NSError(domain: "no id", code: 0, userInfo: nil) }
            
            let url = try await PDFrep.createPlaylistPDF(playlistID: id, title: playlistPDF.title)
            let data = try Data(contentsOf: url)
            return data
        }
        .suggestedFileName { Song.makeValidFilename($0.title) }
        .exportingCondition { playlist in return playlist.includePDF }
    }
}

struct SongTransferable: Transferable, Codable, Identifiable {
    let persistentId: PersistentIdentifier?
    internal let id = UUID()
    let seq: Int
    let title: String
    let srcText: String
    let transpose: Int
    let duration: Double
    let showChords: Bool
    let showText: Bool
    let showHeader: Bool
    let musicItemId: String
    let playerLoops: [PlayerLoop]
    let backgroundColor: Int

    let includeCodable: Bool
    let includeData: Bool
    let includePDF: Bool

    init(from song: Song, includeCodable: Bool = false, includeData: Bool = false, includePDF: Bool = false) {
        self.persistentId = song.id
        self.seq = song.seq
        self.title = song.title
        self.srcText = song.srcText
        self.transpose = song.transpose
        self.showText = song.showText
        self.showHeader = song.showHeader
        self.showChords = song.showChords
        self.duration = song.duration
        self.musicItemId = song.musicItemId
        self.playerLoops = song.playerLoops
        self.backgroundColor = song.backgroundColor
        
        self.includePDF = includePDF
        self.includeData = includeData
        self.includeCodable = includeCodable
    }
    
    enum CodingKeys: CodingKey {
        case persistentid
        case seq
        case title
        case srctext
        case transpose
        case showheader
        case showchords
        case showtext
        case duration
        case musicitemid
        case playerloops
        case backgroundcolor
    }
    
    public init(from decoder: Decoder) throws {
        self.includeCodable = false
        self.includeData = false
        self.includePDF = false

        let container = try decoder.container(keyedBy: CodingKeys.self)
        persistentId = try container.decode(PersistentIdentifier.self, forKey: .persistentid)
        seq = try container.decode(Int.self, forKey: .seq)
        title = try container.decode(String.self, forKey: .title)
        srcText = try container.decode(String.self, forKey: .srctext)
        transpose = try container.decode(Int.self, forKey: .transpose)
        showHeader = try container.decode(Bool.self, forKey: .showheader)
        showChords = try container.decode(Bool.self, forKey: .showchords)
        duration = try container.decode(Double.self, forKey: .duration)
        
        if container.contains(.musicitemid) {
            let mItemId = try container.decode(String.self, forKey: .musicitemid)
            // keine mehrfachen Verweise auf MP3 zulassen
            if mItemId.starts(with: "local@") { musicItemId = "" } else { musicItemId = mItemId }
        } else { musicItemId = "" }

        if container.contains(.playerloops) { playerLoops = try container.decode([PlayerLoop].self, forKey: .playerloops) } else { playerLoops = [] }
        if container.contains(.showtext) { showText = try container.decode(Bool.self, forKey: .showtext) } else { showText = false }
        if container.contains(.backgroundcolor) { backgroundColor = try container.decode(Int.self, forKey: .backgroundcolor) } else { backgroundColor = 0 }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(persistentId, forKey: .persistentid)
        try container.encode(seq, forKey: .seq)
        try container.encode(title, forKey: .title)
        try container.encode(srcText, forKey: .srctext)
        try container.encode(transpose, forKey: .transpose)
        try container.encode(showHeader, forKey: .showheader)
        try container.encode(showChords, forKey: .showchords)
        try container.encode(showText, forKey: .showtext)
        try container.encode(duration, forKey: .duration)
        try container.encode(musicItemId, forKey: .musicitemid)
        try container.encode(playerLoops, forKey: .playerloops)
        try container.encode(backgroundColor, forKey: .backgroundcolor)
    }

    func toUrl(url: URL) throws {
        let data = try toData()
        
        let startSecurityScope = url.startAccessingSecurityScopedResource()
        try data.write(to: url)
        if startSecurityScope { url.stopAccessingSecurityScopedResource() }
    }
    
    static func fromUrl(url: URL) throws -> SongTransferable {
        let startSecurityScope = url.startAccessingSecurityScopedResource()
        let songData = try Data(contentsOf: url)
        if startSecurityScope { url.stopAccessingSecurityScopedResource() }
        return try fromData(data: songData)
    }
    
    func toData() throws -> Data {
        let encoder = JSONEncoder()
        return try encoder.encode(self)
    }
    
    static func fromData(data: Data) throws -> SongTransferable {
        let decoder = JSONDecoder()
        return try decoder.decode(SongTransferable.self, from: data)
    }
    
    func toTempFile(filename: String) throws -> URL {
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileURL = tempDirectory.appendingPathComponent(filename)
        print(fileURL.absoluteString)
        try toUrl(url: fileURL)
        return fileURL
    }
    
    public static var transferRepresentation: some TransferRepresentation {
        // Endung .songchords
        CodableRepresentation(contentType: .songJSON)
        .suggestedFileName { Song.makeValidFilename($0.title) }
        .exportingCondition { song in return song.includeCodable }

        // Nur für DragDrop auf außerhalb
        DataRepresentation(exportedContentType: .fileURL) { song in
            let url = try song.toTempFile(filename: "\(Song.makeValidFilename(song.title)).songchords")
            return url.dataRepresentation
        }
        .exportingCondition { song in return song.includeData } // soll beim File-Exporter nicht erscheinen
        
        // für fileExporter-Auswahl
        DataRepresentation(exportedContentType: .pdf) { songPDF in
            let PDFrep = PDFHelper()

            guard let id = songPDF.persistentId else { throw NSError(domain: "no id", code: 0, userInfo: nil) }
            
            let url = try await PDFrep.createSongPDF(id: id, title: songPDF.title)
            let data = try Data(contentsOf: url)
            return data
        }
        .suggestedFileName { Song.makeValidFilename($0.title) }
        .exportingCondition { song in return song.includePDF }
    }
}

//
// Transferable für .dropDestination. Erweiterung für mehrere Typen (SongTransferable, URL)
//
enum SongDropItem {
    case song(SongTransferable)
    case file(URL)
//    case data(Data)
}

struct SongDropTransferable: Transferable {
    let items: [SongDropItem]

    static var transferRepresentation: some TransferRepresentation {
        // Einzelner Song
        ProxyRepresentation { (song: SongTransferable) in
            SongDropTransferable(items: [.song(song)])
        }
        // Einzelne URL
        ProxyRepresentation { (url: URL) in
            SongDropTransferable(items: [.file(url)])
        }
        // Data
//        ProxyRepresentation { (data: Data) in
//            SongDropTransferable(items: [.data(data)])
//        }
    }
}

// Global access point for a ModelContainer used by wrappers to export Files.
// Set this once during app startup, e.g., in the App struct after creating the container.
struct GlobalModelContainer {
    static var shared: ModelContainer?
}

struct PDFHelper {
    func createSongPDF(id: PersistentIdentifier, title: String) async throws -> URL {
        print("FileRepresentation (.pdf) exported song \(title)")
        
        do {
            let userSettings = UserSettings()
            let defaultPaper = MediaBoxes.getBox(name: userSettings.mediabox)
            let modelContainer: ModelContainer? = GlobalModelContainer.shared
            guard let modelContainer else { throw NSError(domain: "PDFCreationError", code: 5, userInfo: ["reason": "Missing ModelContainer for PDF export"]) }
            let delegate = await PrintSongDelegate(songID: id, modelContainer: modelContainer)
            guard let delegate = delegate, let pdfUrl = delegate.createPDF(paperSize: defaultPaper) else {
                throw NSError(domain: "PDFCreationError", code: 4, userInfo: ["reason": "Failed to create PDF"])
            }
            let url1 = pdfUrl.deletingLastPathComponent()
            let url2 = url1.appendingPathComponent(Song.makeValidFilename(title) + ".pdf")
            if FileManager.default.fileExists(atPath: url2.path) {
                try FileManager.default.removeItem(at: url2)
            }
            try FileManager.default.copyItem(at: pdfUrl, to: url2)
            return url2
        } catch {
            print("Fehler beim Exportieren von PDF: \(error.localizedDescription)")
            throw error
        }
    }
    
    func createPlaylistPDF(playlistID: PersistentIdentifier, title: String) async throws -> URL {
        print("FileRepresentation (.pdf) exported playlist \(title)")
        
        do {
            let userSettings = UserSettings()
            let defaultPaper = MediaBoxes.getBox(name: userSettings.mediabox)
            let modelContainer: ModelContainer? = GlobalModelContainer.shared
            guard let modelContainer else { throw NSError(domain: "PDFCreationError", code: 5, userInfo: ["reason": "Missing ModelContainer for PDF export"]) }
            let delegate = PrintSetlistDelegate(playlistID: playlistID, modelContainer: modelContainer)
            guard let delegate = delegate, let pdfUrl = delegate.createPDF(paperSize: defaultPaper) else {
                throw NSError(domain: "PDFCreationError", code: 4, userInfo: ["reason": "Failed to create PDF"])
            }
            let url1 = pdfUrl.deletingLastPathComponent()
            let url2 = url1.appendingPathComponent(Song.makeValidFilename(title) + ".pdf")
            if FileManager.default.fileExists(atPath: url2.path) {
                try FileManager.default.removeItem(at: url2)
            }
            try FileManager.default.copyItem(at: pdfUrl, to: url2)
            return url2
        } catch {
            print("Fehler beim Exportieren von PDF: \(error.localizedDescription)")
            throw error
        }
    }
}
