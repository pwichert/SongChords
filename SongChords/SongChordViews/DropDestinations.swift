//
//  DropDestinations.swift
//  SongChords
//
//  Created by Peter Wichert on 23.12.24.
//

import SwiftUI
import SwiftData

extension PlayListView {
    public func dropDestinationItems(dropItems: [SongDropTransferable], playlist: PlayList, modelContext: ModelContext) throws {
        print("drop in Playlist \(playlist.title)")
        
        for receivedSong in dropItems.flatMap(\.items) {
            switch receivedSong {
            case .song(let song):
                try dropDestinationSong(playlist: playlist, song: song, modelContext: modelContext)
            case .file(let url):
                try dropDestinationURL(playlist: playlist, url: url, modelContext: modelContext)
            }
        }
    }
    
    private func dropDestinationURL(playlist: PlayList, url: URL, modelContext: ModelContext) throws {
        print(".dropDestinationURL: received \(url) for playlist \(playlist.title)")

        // Playlist- oder Song-URL?
        if let song = try? SongTransferable.fromUrl(url: url)  {
            try playlist.sortAndCopyCodable(songs: [song], modelContext: modelContext)
            try modelContext.save()
            
            print("song-url von \(song.title)")
        } else {
            let playlist = try PlayListTransferable.fromUrl(url: (url))
            let newPlaylist = try PlayList(modelContext: modelContext, title: playlist.title)
            modelContext.insert(newPlaylist)
            try newPlaylist.sortAndCopyCodable(songs: playlist.songs, modelContext: modelContext)
            try modelContext.save()
            print("playlist-url von \(playlist.title) mit \(playlist.songs.count) Songs")
        }
    }

    private func dropDestinationSong(playlist: PlayList, song: SongTransferable, modelContext: ModelContext) throws {
        print(".dropDestinationSong: received \(song.title) for playlist \(playlist.title)")
        
        try playlist.sortAndCopyCodable(songs: [song], modelContext: modelContext)
        try modelContext.save()
    }   
}
