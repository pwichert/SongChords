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
            print("dropDestinationURL: song-url von \(song.title)")
            try playlist.sortAndCopyCodable(songs: [song], modelContext: modelContext)
            try modelContext.save()
        } else {
            let playlist = try PlayListTransferable.fromUrl(url: (url))
            let newPlaylist = try PlayList(modelContext: modelContext, title: playlist.title)
            modelContext.insert(newPlaylist)
            try newPlaylist.sortAndCopyCodable(songs: playlist.songs, modelContext: modelContext)
            try modelContext.save()
            print("dropDestinationURL: playlist-url von \(playlist.title) mit \(playlist.songs.count) Songs")
        }
    }

    private func dropDestinationSong(playlist: PlayList, song: SongTransferable, modelContext: ModelContext) throws {
        if let s = Song.fetchSong(with: song.persistentId, in: modelContext) {
            print(".dropDestinationSong: received \(song.title) for playlist \(playlist.title), playlist origin \(s.playlist?.title ?? "??")")
            
            if s.playlist?.persistentModelID == playlist.persistentModelID {
                print("keine Aktion, identische Playlist")
                return
            }
            
            // Hier darf der MP3-Verweis übernommen werden, da der Song verschoben und nicht kopiert wird.
            s.toPlaylist(playlist: playlist)
            try modelContext.save()
        } else {
            print(".dropDestinationSong: song nicht gefunden, \(song.title) for playlist \(playlist.title)")
        }
    }
}
