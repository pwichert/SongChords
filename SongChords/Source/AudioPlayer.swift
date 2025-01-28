//
//  AudioPlayer.swift
//  SongChords
//
//  Created by Peter Wichert on 20.01.25.
//

import SwiftUI
import MusicKit

enum PlayerState: String, CaseIterable, Sendable {
    case playing
    case stopped
    case paused
}

@Observable
@MainActor
class AudioPlayer {
    /// The MusicKit player to use for Apple Music playback.
    let player = ApplicationMusicPlayer.shared
    
    private(set) var songDuration: TimeInterval = 0.0
    
    var songPosition: TimeInterval { get {
        return player.playbackTime
    } set {
        player.playbackTime = newValue
    }}
    
    // Speed-Änderung started den Player, daher Status merken und restaurieren
    private var songSpeed_: Float = 1.0
    var songSpeed: Float { get {
        return songSpeed_
    } set {
        songSpeed_ = newValue
        let state = player.state.playbackStatus
        player.state.playbackRate = newValue
        restoreState(state: state)
    }}
    
    var playerState: MusicPlayer.PlaybackStatus { return player.state.playbackStatus }
    var isAllowed: Bool { return musicAuthorizationStatus == .authorized }

    private var loadedId: String?
    var isLoaded: Bool { return songResponse != nil }

    private var musicAuthorizationStatus: MusicAuthorization.Status = .notDetermined
    private var songResponse: MusicCatalogResourceResponse<MusicKit.Song>?

    init() {
        handleAuthorizationStatus()
    }

    func play() {
        print("Audioplayer play")
        let pl = player
        Task { @MainActor in
            do {
                try await pl.play()
                pl.state.playbackRate = songSpeed_
            } catch (let error) {
                print(error)
            }
        }
    }
    
    func stop() {
        print("Audioplayer stop")
        player.restartCurrentEntry()
        player.stop()
    }
    
    func pause() {
        print("Audioplayer pause")
        player.pause()
    }
    
    func load(id: String) {
        print("Audioplayer loadSong")
        
        if id == loadedId { return }

        player.stop()
        songResponse = nil
        songDuration = 0
        player.queue = []
        loadedId = nil
        
        if id.isEmpty { return }
        let pl = player
        
        Task { @MainActor in
            do {
                let songRequest = MusicCatalogResourceRequest<MusicKit.Song>(matching: \.id, equalTo: MusicItemID(rawValue: id)) // MusicItemID(rawValue: "83445997"))
                songResponse = try await songRequest.response()
                
                if let songItem = songResponse?.items.first {
                    songDuration = songItem.duration ?? 0
                    songPosition = 0
                    player.queue = [songItem]
                    loadedId = id
                    print("Audioplayer geladen \(songDuration)")
                    try await pl.prepareToPlay()
                }
            } catch (let error) {
                print(error)
            }
        }
    }
    
    private func restoreState(state: MusicPlayer.PlaybackStatus) {
        print("Audioplayer restoring \(state)")
        switch state {
        case .playing:
            // setzen der Rate started immer das playing, daher hier nicht nochmal
            break
        case .stopped:
            player.stop()
        case .paused:
            player.pause()
        case .interrupted:
            player.stop()
        case .seekingForward:
            break
        case .seekingBackward:
            break
        @unknown default:
            break
        }
    }
    
    func handleAuthorizationStatus() {
        switch musicAuthorizationStatus {
        case .notDetermined:
            Task { @MainActor in
                let musicAuthorizationStatus = await MusicAuthorization.request()
                update(with: musicAuthorizationStatus)
            }
        default:
            print("Audioplayer musicAuthorizationStatus = \(self.musicAuthorizationStatus)")
        }
    }
    
    private func update(with musicAuthorizationStatus: MusicAuthorization.Status) {
        self.musicAuthorizationStatus = musicAuthorizationStatus
        print("Audioplayer update musicAuthorizationStatus \(self.musicAuthorizationStatus)")
    }
}
