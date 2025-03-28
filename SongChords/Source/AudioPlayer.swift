//
//  AudioPlayer.swift
//  SongChords
//
//  Created by Peter Wichert on 20.01.25.
//

import SwiftUI
import MusicKit
import AVFoundation

@MainActor
protocol AudioPlayerProtocol {
    var songSpeed: Float { get set }
    var songPosition: TimeInterval { get set }
    var songPitch: Float { get set }
    var songDuration: TimeInterval { get }
    var playerState: MusicKit.MusicPlayer.PlaybackStatus { get }
    var isAllowed: Bool { get }
    var isLoaded: Bool { get }
    
    func handleAuthorizationStatus()
    func load(song: Song) async -> Bool
    func loadAndPlay(song: Song) async -> Bool
    func play() async -> Bool
    func stop()
    func pause()
}

@Observable
@MainActor
class AudioPlayer {
    private var localPlayer = MP3AudioPlayer()
    private var applicationPlayer = ApplicationPlayer()

    var isMP3Player: Bool = false
    
    private var player: AudioPlayerProtocol {
        return isMP3Player ? localPlayer : applicationPlayer
    }

    var songSpeed: Float { get { return player.songSpeed } set {
        var pl = player
        pl.songSpeed = newValue
    }}
    
    var songPitch: Float { get { return player.songPitch } set {
        var pl = player
        pl.songPitch = newValue
    }}

    var songPosition: Double { get { return player.songPosition } set {
        var pl = player
        pl.songPosition = newValue
    }}
    
    var playerState: MusicKit.MusicPlayer.PlaybackStatus { get { return player.playerState }}
    
    var isAllowed: Bool { get { return applicationPlayer.isAllowed }}
    
    var someIsLoaded: Bool { get { return localPlayer.isLoaded || applicationPlayer.isLoaded }}
    
    var songDuration: TimeInterval { get { return player.songDuration }}
        
    func load(song: Song) async -> Bool {
        isMP3Player = song.musicItemId.starts(with: "local@")
        return await player.load(song: song)
    }

    func loadAndPlay(song: Song) async -> Bool {
        isMP3Player = song.musicItemId.starts(with: "local@")
        return await player.loadAndPlay(song: song)
    }

    func play() async -> Bool {
        return await player.play()
    }
    
    func stopAll() {
        localPlayer.stop()
        applicationPlayer.stop()
    }
    
    func pause() {
        player.pause()
    }
    
    func handleAuthorizationStatus() {
        return applicationPlayer.handleAuthorizationStatus()
    }
}

@Observable
@MainActor
class ApplicationPlayer: AudioPlayerProtocol {
    /// The MusicKit player to use for Apple Music playback.
    private var player: ApplicationMusicPlayer { get { ApplicationMusicPlayer.shared }}
    
    var songDuration: TimeInterval = 0.0
    var songPosition: TimeInterval { get { return player.playbackTime } set { player.playbackTime = newValue }}
    var songPitch: Float { get { return 0 } set { }}

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
    
    var playerState: MusicKit.MusicPlayer.PlaybackStatus { return player.state.playbackStatus }
    var isAllowed: Bool { return musicAuthorizationStatus == .authorized }

    private var loadedId: String?
    var isLoaded: Bool { return songResponse != nil }

    private var musicAuthorizationStatus: MusicAuthorization.Status = .notDetermined
    private var songResponse: MusicCatalogResourceResponse<MusicKit.Song>?

    // Speichert die aktuelle Player-Task. Bei false ist ein Fehler aufgetreten.
    private var playerTask: Task<Bool, Never>?
    
    init() {
        handleAuthorizationStatus()
    }
    
    func play() async -> Bool {
        print("Audioplayer play")
         
        playerTask?.cancel()
        
        let pl = player
        
        playerTask = Task {
            do {
                // Falls die Task während des Starts abgebrochen wird, direkt raus
                if Task.isCancelled { return true }
                
                try await pl.play()
                
                // Falls die Task während des Wartens abgebrochen wird, nicht weiter ausführen
                if Task.isCancelled { return true }
                
                pl.state.playbackRate = songSpeed_
                print("Wiedergabe gestartet mit Speed \(songSpeed_)")
            } catch {
                print("Fehler beim Starten der Wiedergabe: \(error)")
                return false
            }
            
            return true
        }
        
        // Optional: Falls der Aufruf blockierend sein soll, auf Task-Ende warten
        let ret = await playerTask?.value
        playerTask = nil
        return ret ?? true
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
    
    func loadAndPlay(song: Song) async -> Bool {
        print("Audioplayer loadAndPlay")
        
        let id = song.musicItemId
        if id == loadedId { return await play() }
        
        playerTask?.cancel()
        
        if id.isEmpty { return true }
        let pl = player
        
        playerTask = Task {
            do {
                player.stop()
                songResponse = nil
                songDuration = 0
                player.queue = []
                loadedId = nil
                
                if Task.isCancelled { return true }
                
                let songRequest = MusicCatalogResourceRequest<MusicKit.Song>(matching: \.id, equalTo: MusicItemID(rawValue: id)) // MusicItemID(rawValue: "83445997"))
                songResponse = try await songRequest.response()
                
                if Task.isCancelled { return true }
                
                if let songItem = songResponse?.items.first {
                    songDuration = songItem.duration ?? 0
                    songPosition = 0
                    player.queue = [songItem]
                    loadedId = id
                    
                    print("Audioplayer geladen \(songDuration)")
                    try? await pl.prepareToPlay()
                    if Task.isCancelled { return true }
                    
                    print("Audioplayer play")
                    try await pl.play()
                    if Task.isCancelled { return true }
                    
                    pl.state.playbackRate = songSpeed_
                    print("Wiedergabe gestartet mit Speed \(songSpeed_)")
                }
            } catch (let error) {
                print(error)
                loadedId = nil
                return false
            }
            
            return true
        }
        
        // Optional: Falls der Aufruf blockierend sein soll, auf Task-Ende warten
        let ret = await playerTask?.value
        playerTask = nil
        return ret ?? true
    }
    
    func load(song: Song) async -> Bool {
        print("Audioplayer load")
        
        let id = song.musicItemId
        if id == loadedId { return true }

        playerTask?.cancel()
        
        if id.isEmpty { return true }
        let pl = player
        
        playerTask = Task {
            do {
                player.stop()
                songResponse = nil
                songDuration = 0
                player.queue = []
                loadedId = nil

                if Task.isCancelled { return true }

                let songRequest = MusicCatalogResourceRequest<MusicKit.Song>(matching: \.id, equalTo: MusicItemID(rawValue: id)) // MusicItemID(rawValue: "83445997"))
                songResponse = try await songRequest.response()
                
                if Task.isCancelled { return true }

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
                loadedId = nil
                return false
            }
            
            return true
        }
        
        // Optional: Falls der Aufruf blockierend sein soll, auf Task-Ende warten
        let ret = await playerTask?.value
        playerTask = nil
        return ret ?? true
    }
    
    private func restoreState(state: MusicKit.MusicPlayer.PlaybackStatus) {
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

@Observable
@MainActor
class MP3AudioPlayer: AudioPlayerProtocol {
    var songPosition: TimeInterval { get { return getCurrentTime() + lastSeekTime } set { seek(to: newValue) }}
    var songDuration: TimeInterval = 0.0
    
    // range: -2400..2400
    // ein halbton = 100 Cents
    var songPitch: Float { get { return timePitch.pitch } set { timePitch.pitch = newValue }}
    var songSpeed: Float { get { return timePitch.rate } set { timePitch.rate = newValue }}

    var playerState: MusicKit.MusicPlayer.PlaybackStatus = .stopped
    
    var isAllowed: Bool = true
    
    private var loadedId: String?
    var isLoaded: Bool { return loadedId != nil }
    
    private var audioEngine = AVAudioEngine()
    private var audioPlayerNode = AVAudioPlayerNode()
    private var lastSeekTime: TimeInterval = 0.0
    private var timePitch = AVAudioUnitTimePitch()
    private var audioFile: AVAudioFile?
    private var sampleRate: Double = 44100 // Standard-Sample-Rate
    private var audioVolume: Float = 1.0
    
    init() {
        setupAudioEngine()
    }
    
    func handleAuthorizationStatus() { }
    
    private func setupAudioEngine() {
        audioEngine.attach(audioPlayerNode)
        audioEngine.attach(timePitch)
        
        let mainMixer = audioEngine.mainMixerNode
        audioEngine.connect(audioPlayerNode, to: timePitch, format: nil)
        audioEngine.connect(timePitch, to: mainMixer, format: nil)
        audioEngine.connect(mainMixer, to: audioEngine.outputNode, format: nil) // Mixer → Output
    }
    
    func loadAndPlay(song: Song) async -> Bool {
        print("MP3AudioPlayer loadAndPlay")
        
        let uuid = song.getMP3FileInfo() ?? ""
        if uuid == loadedId { return play() }
        
        loadedId = nil

        let res = await load(song: song)
        if !res { return false }
        
        return play()
    }
    
    func load(song: Song) async -> Bool {
        do {
            let (file, pitch) = try song.getMP3Info()
            
            print("MP3AudioPlayer load id: \(file) loaded: \(loadedId ?? "")")
            
            if file == loadedId { return true }
            
            audioPlayerNode.stop()
            lastSeekTime = 0
            
            let destDir = try GlobalFunctions.mp3Path()
            let filePath = destDir.appendingPathComponent(file + ".mp3")

            audioFile = try AVAudioFile(forReading: filePath)
            
            if let audioFile = audioFile {
                sampleRate = audioFile.processingFormat.sampleRate
                songPitch = pitch
                audioVolume = adjustVolume(for: audioFile)
                print("volume \(audioVolume)")
                let frameCount = AVAudioFrameCount(audioFile.length)
                songDuration = Double(frameCount) / sampleRate
                loadedId = file
                return true
            }
        } catch {
            print("Fehler beim Laden der Datei: \(error)")
        }
        
        loadedId = nil
        return false
    }
    
    func play() -> Bool {
        print("MP3AudioPlayer play")
        
        guard audioFile != nil else { return true }
        
        if !audioEngine.isRunning {
            try? audioEngine.start()
        }
        
        if audioPlayerNode.isPlaying {
            return true // Läuft bereits
        }
        
        seek(to: lastSeekTime)
        audioEngine.mainMixerNode.outputVolume = audioVolume
        audioPlayerNode.play()
        
        playerState = .playing

        return true
    }
    
    func stop() {
        print("MP3AudioPlayer stop")
        
        audioPlayerNode.stop()
        lastSeekTime = 0
        
        playerState = .stopped
    }
    
    func pause() {
        print("MP3AudioPlayer pause")
        
        guard audioPlayerNode.isPlaying else { return }
        
        lastSeekTime = songPosition
        audioPlayerNode.pause()
        playerState = .paused
    }
    
    private func seek(to seconds: TimeInterval) {
        guard let audioFile = audioFile else { return }
        
        let framePosition = AVAudioFramePosition(seconds * Double(sampleRate))
        let frameCount = AVAudioFrameCount(audioFile.length - framePosition)
        
        if framePosition >= audioFile.length {
            print("Seek-Zeit liegt außerhalb der Datei.")
            return
        }
        
        lastSeekTime = seconds
        
        audioPlayerNode.stop()
        audioPlayerNode.scheduleSegment(audioFile, startingFrame: framePosition, frameCount: frameCount, at: nil, completionHandler: nil)
        
        if playerState == .playing {
            audioPlayerNode.play()
        }
    }
    
    private func getCurrentTime() -> TimeInterval {
        guard let lastRenderTime = audioPlayerNode.lastRenderTime,
              let playerTime = audioPlayerNode.playerTime(forNodeTime: lastRenderTime) else {
            return 0
        }
        
        let res = Double(playerTime.sampleTime) / Double(sampleRate)

        if res + lastSeekTime >= songDuration {
            print("Playback beendet.")
            self.stop()
        }
        
        return res
    }
    
    private func adjustVolume(for file: AVAudioFile) -> Float {
        let sampleRate = file.processingFormat.sampleRate
        let duration: TimeInterval = 30
        let frameCount = AVAudioFrameCount(min(Double(file.length), duration * sampleRate)) // Anzahl zu lesender Frames
        
        let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: frameCount)
        guard let buffer = buffer else { return 1.0 }
        
        do {
            try file.read(into: buffer) // Liest nur den Anfang der Datei
        } catch {
            print("Fehler beim Einlesen der Datei: \(error)")
            return 1.0
        }
        
        let channelData = buffer.floatChannelData?[0]
        let frameLength = Int(buffer.frameLength)
        
        guard let data = channelData, frameLength > 0 else { return 1.0 }
        
        // RMS berechnen (Root Mean Square)
        var sum: Float = 0
        for i in 0..<frameLength {
            sum += data[i] * data[i]
        }
        let rms = sqrt(sum / Float(frameLength))
        //print("rms \(rms)")
        
        // Ziel-RMS setzen
        let targetRMS: Float = 0.1  // experimentell ausprobieren
        let volumeAdjustment = targetRMS / max(rms, 0.01) // Schutz vor Division durch 0
        
        // Lautstärkeverhältnis MP3 zu Streaming anpassen.
        #if os(macOS)
        let dampingFactor: Float = 1.2
        #else
        let dampingFactor: Float = 0.8
        #endif
        let totalAdjustment = volumeAdjustment * dampingFactor
        
        return min(max(totalAdjustment, 0.1), 2.0) // Lautstärke auf sinnvolle Werte begrenzen
    }
}
