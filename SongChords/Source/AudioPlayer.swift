//
//  AudioPlayer.swift
//  SongChords
//
//  Created by Peter Wichert on 20.01.25.
//

import SwiftUI
import MusicKit

@Observable
@MainActor
class AudioPlayer {
    /// The MusicKit player to use for Apple Music playback.
    private let player = ApplicationMusicPlayer.shared
    
    private(set) var songDuration: TimeInterval = 0.0
    var songPosition: TimeInterval { get { return player.playbackTime } set { player.playbackTime = newValue }}
    
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

    private var playerTask: Task<Void, Never>? // Speichert die aktuelle Player-Task

    init() {
        handleAuthorizationStatus()
    }
    
    func play() async {
        print("Audioplayer play")
        
        // Falls bereits ein Play-Vorgang läuft, abbrechen
        playerTask?.cancel()
        
        let pl = player
        
        playerTask = Task {
            do {
                // Falls die Task während des Starts abgebrochen wird, direkt raus
                if Task.isCancelled { return }
                
                try await pl.play()
                
                // Falls die Task während des Wartens abgebrochen wird, nicht weiter ausführen
                if Task.isCancelled { return }
                
                pl.state.playbackRate = songSpeed_
                print("Wiedergabe gestartet mit Speed \(songSpeed_)")
            } catch {
                print("Fehler beim Starten der Wiedergabe: \(error)")
            }
        }
        
        // Optional: Falls der Aufruf blockierend sein soll, auf Task-Ende warten
        await playerTask?.value
        playerTask = nil
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
    
    func loadAndPlay(id: String) async {
        print("Audioplayer loadAndPlay")
        
        if id == loadedId { await play(); return }

        // Falls bereits ein loadAndPlay-Vorgang läuft, abbrechen
        playerTask?.cancel()
        
        if id.isEmpty { return }
        let pl = player
        
        playerTask = Task {
            do {
                player.stop()
                songResponse = nil
                songDuration = 0
                player.queue = []
                loadedId = nil
                
                if Task.isCancelled { return }

                let songRequest = MusicCatalogResourceRequest<MusicKit.Song>(matching: \.id, equalTo: MusicItemID(rawValue: id)) // MusicItemID(rawValue: "83445997"))
                songResponse = try await songRequest.response()
                
                if Task.isCancelled { return }

                if let songItem = songResponse?.items.first {
                    songDuration = songItem.duration ?? 0
                    songPosition = 0
                    player.queue = [songItem]
                    loadedId = id
                    
                    print("Audioplayer geladen \(songDuration)")
                    try? await pl.prepareToPlay()
                    if Task.isCancelled { return }

                    print("Audioplayer play")
                    try await pl.play()
                    if Task.isCancelled { return }

                    pl.state.playbackRate = songSpeed_
                    print("Wiedergabe gestartet mit Speed \(songSpeed_)")
                }
            } catch (let error) {
                print(error)
            }
        }
        
        // Optional: Falls der Aufruf blockierend sein soll, auf Task-Ende warten
        await playerTask?.value
        playerTask = nil
    }
    
    func load(id: String) async {
        print("Audioplayer load")
        
        if id == loadedId { return }

        // Falls bereits ein loadTask-Vorgang läuft, abbrechen
        playerTask?.cancel()
        
        if id.isEmpty { return }
        let pl = player
        
        playerTask = Task {
            do {
                player.stop()
                songResponse = nil
                songDuration = 0
                player.queue = []
                loadedId = nil

                if Task.isCancelled { return }

                let songRequest = MusicCatalogResourceRequest<MusicKit.Song>(matching: \.id, equalTo: MusicItemID(rawValue: id)) // MusicItemID(rawValue: "83445997"))
                songResponse = try await songRequest.response()
                
                if Task.isCancelled { return }

                if let songItem = songResponse?.items.first {
                    songDuration = songItem.duration ?? 0
                    songPosition = 0
                    player.queue = [songItem]
                    loadedId = id
                    print("Audioplayer geladen \(songDuration)")
                    try? await pl.prepareToPlay()
                }
            } catch (let error) {
                print(error)
            }
        }
        
        // Optional: Falls der Aufruf blockierend sein soll, auf Task-Ende warten
        await playerTask?.value
        playerTask = nil
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
