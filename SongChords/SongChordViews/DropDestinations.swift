//
//  DropDestinations.swift
//  SongChords
//
//  Created by Peter Wichert on 23.12.24.
//

import SwiftUI
import SwiftData

extension PlayListView {
    public func dropDestinationData(playlist: PlayList, data: [Data], modelContext: ModelContext) -> Bool {
        print(".dropDestination: received (Data) \(data) for playlist \(playlist.title)")
        var songs = songsFromDatas(data: data)
        
        if (songs ?? []).isEmpty { songs = songsFromIDStrings(data: data, modelContext: modelContext) }

        if (songs ?? []).isEmpty { print("no result"); return false }
        
        playlist.sortedInsert(songs: songs)
        try? modelContext.save()
        
        for s in songs ?? [] { print(s.title) }
        return true
    }
    
    public func dropDestinationURL(playlist: PlayList, url: [URL], modelContext: ModelContext) -> Bool {
        print(".dropDestination: received (URL) \(url) for playlist \(playlist.title)")
        let songs = songsFromURLs(url: url)
        
        if (songs ?? []).isEmpty { print("no result"); return false }
        
        playlist.sortedInsert(songs: songs)
        try? modelContext.save()
        
        for s in songs ?? [] { print(s.title) }
        return true
    }
    
    public func dropDestinationSongs(playlist: PlayList, songs: [Song], modelContext: ModelContext) -> Bool {
        print(".dropDestination: received (Songs) \(songs) for playlist \(playlist.title)")
        if songs.isEmpty { print("no result"); return false }
        
        playlist.sortedInsert(songs: songs)
        try? modelContext.save()
        
        for s in songs { print(s.title) }
        return true
    }
    
    private func songsFromURLs(url: [URL]) -> [Song]? {
        do {
            return try url.compactMap { try Song.fromUrl(url: $0) }
        } catch {
            return nil
        }
    }
    
    private func songsFromDatas(data: [Data]) -> [Song]? {
        do {
            return try data.compactMap { try Song.fromData(data: $0) }
        } catch {
            return nil
        }
    }
    
    private func songsFromIDStrings(data: [Data], modelContext: ModelContext) -> [Song]? {
        do {
            let strings: [String] = data.compactMap { String(data: $0, encoding: .utf8) }
            let IDs: [PersistentIdentifier] = try strings.compactMap { try PersistentIdentifier.fromString($0) }
            return Song.fetchSongs(with: Set(IDs), in: modelContext)
        } catch {
            return nil
        }
    }
}
