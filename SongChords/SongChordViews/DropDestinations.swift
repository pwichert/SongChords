//
//  DropDestinations.swift
//  SongChords
//
//  Created by Peter Wichert on 23.12.24.
//

import SwiftUI
import SwiftData

extension PlayListView {
    public func dropDestinationData(playlist: PlayList, data: [Data], modelContext: ModelContext, store: SongChordsStore) throws -> Bool {
        print(".dropDestination: received (Data) \(data) for playlist \(playlist.title)")
        // erster Versuch mit Data
        var songs = try? songsFromDatas(data: data)
        
        // zweiter Versuch mit PersistentIdentifier als Strings
        if (songs ?? []).isEmpty { songs = try songsFromIDStrings(data: data, modelContext: modelContext) }

        if (songs ?? []).isEmpty { print("no result"); return false }
        
        try playlist.sortAndCopy(songs: songs, modelContext: modelContext, store: store)
        try modelContext.save()
        
        for s in songs ?? [] { print(s.title) }
        return true
    }
    
    public func dropDestinationURL(playlist: PlayList, url: [URL], modelContext: ModelContext, store: SongChordsStore) throws -> Bool {
        print(".dropDestination: received (URL) \(url) for playlist \(playlist.title)")
        let songs = try songsFromURLs(url: url)
        
        if songs.isEmpty { print("no result"); return false }
        
        try playlist.sortAndCopy(songs: songs, modelContext: modelContext, store: store)
        try modelContext.save()
        
        for s in songs { print(s.title) }
        return true
    }
    
    public func dropDestinationSongs(playlist: PlayList, songs: [Song], modelContext: ModelContext, store: SongChordsStore) throws -> Bool {
        print(".dropDestination: received (Songs) \(songs) for playlist \(playlist.title)")
        if songs.isEmpty { print("no result"); return false }
        
        try playlist.sortAndCopy(songs: songs, modelContext: modelContext, store: store)
        try modelContext.save()
        
        for s in songs { print(s.title) }
        return true
    }
    
    private func songsFromURLs(url: [URL]) throws -> [Song] {
        return try url.compactMap { try Song.fromUrl(url: $0) }
    }
    
    private func songsFromDatas(data: [Data]) throws -> [Song] {
        return try data.compactMap { try Song.fromData(data: $0) }
    }
    
    private func songsFromIDStrings(data: [Data], modelContext: ModelContext) throws -> [Song] {
        let strings: [String] = data.compactMap { String(data: $0, encoding: .utf8) }
        let IDs: [PersistentIdentifier] = try strings.compactMap { try PersistentIdentifier.SCfromString($0) }
        return Song.fetchSongs(with: Set(IDs), in: modelContext)
    }
}
