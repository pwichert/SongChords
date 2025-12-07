//
//  DropDestinations.swift
//  SongChords
//
//  Created by Peter Wichert on 23.12.24.
//

import SwiftUI
import SwiftData

extension PlayListView {
//    public func dropDestinationData(playlist: PlayList, data: [Data], modelContext: ModelContext, store: SongChordsStore) throws -> Bool {
//        print(".dropDestination: received (Data) \(data) for playlist \(playlist.title)")
//        // erster Versuch mit Data
//        let songs = try? songsFromDatas(data: data)
//        
//        if (songs ?? []).isEmpty { print("no result"); return false }
//        
//        try playlist.sortAndCopyCodable(songs: songs, modelContext: modelContext, store: store)
//        try modelContext.save()
//        
//        for s in songs ?? [] { print(s.title) }
//        return true
//    }
    
    public func dropDestinationURL(playlist: PlayList, url: [URL], modelContext: ModelContext, store: SongChordsStore) throws -> Bool {
        print(".dropDestination: received (URL) \(url) for playlist \(playlist.title)")

        // Playlist- oder Song-URL?
        if let songs = try? songsFromURLs(url: url) {
            try playlist.sortAndCopyCodable(songs: songs, modelContext: modelContext, store: store)
            try modelContext.save()
            
            for s in songs { print(s.title) }
            return true
        } else {
            if let url = url.first {
                let playlist = try PlayListTransferable.fromUrl(url: (url))
                let newPlaylist = try PlayList(modelContext: modelContext, title: playlist.title)
                modelContext.insert(newPlaylist)
                try newPlaylist.sortAndCopyCodable(songs: playlist.songs, modelContext: modelContext, store: store)
                try modelContext.save()
                return true
            }
        }
        
        return false
    }

    public func dropDestinationSongs(playlist: PlayList, songs: [SongTransferable], modelContext: ModelContext, store: SongChordsStore) throws -> Bool {
        print(".dropDestinationSongs: received (Songs) \(songs) for playlist \(playlist.title)")
        if songs.isEmpty { print("no result"); return false }
        
        try playlist.sortAndCopyCodable(songs: songs, modelContext: modelContext, store: store)
        try modelContext.save()
        
        for s in songs { print(s.title) }
        return true
    }
    
    private func songsFromURLs(url: [URL]) throws -> [SongTransferable] {
        return try url.compactMap { try SongTransferable.fromUrl(url: $0) }
    }
    
//    private func songsFromDatas(data: [Data]) throws -> [SongTransferable] {
//        return try data.compactMap { try SongTransferable.fromData(data: $0) }
//    }    
}
