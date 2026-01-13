//
//  AudioEngine.swift
//  SongChords
//
//  Created by Peter Wichert on 12.01.26.
//

// AudioEngine (protocol)
//    ↑
// AppleMusicEngine
// MP3Engine
//    ↑
// UnifiedAudioPlayer   ← SwiftUI benutzt nur diesen

import SwiftUI
import MusicKit
import AVFoundation

enum PlayerError: Error, LocalizedError {
    case notFound
    case invalidMP3Info
    case noAppleMusic
    
    var errorDescription: String? {
        switch self {
        case .notFound: return String(localized: "not found")
        case .invalidMP3Info: return String(localized: "invalid MP3 info")
        case .noAppleMusic: return String(localized: "no Apple Music")
        }
    }
}

enum PlayerState {
    case stopped
    case loading
    case playing
    case paused
    case failed
    
    func toString() -> String {
        switch self {
        case .stopped: return "stopped"
        case .loading: return "loading"
        case .playing: return "playing"
        case .paused: return "paused"
        case .failed: return "failed"
        }
    }
}

protocol AudioEngine {
    var duration: TimeInterval { get }
    var position: TimeInterval { get set }
    var rate: Float { get set }
    var pitch: Float { get set }
    var state: PlayerState { get }
    
    func load(song: Song) async throws
    func play() async throws
    func pause()
    func stop()
    func isLoaded() -> Bool
    
    func setPosition(position: TimeInterval)
    func setPitch(pitch: Double)
    func setRate(rate: Double)
}

@Observable
final class AudioPlayerII {    
    @ObservationIgnored
    private var engine: AudioEngine?

    private(set) var state: PlayerState = .stopped
    private(set) var duration: TimeInterval = 0
    private(set) var position: TimeInterval = 0
    private(set) var rate: Float = 1.0
    private(set) var pitch: Float = 0

    private(set) var positionSeconds: TimeInterval = 0

    @ObservationIgnored
    private var ticker: Task<Void, Never>?

    @ObservationIgnored
    private var tickerStart: Date?
        
    isolated
    deinit {
        print("AudioPlayer deinit")
        stop()
    }
    
    func isLoaded() -> Bool {
        engine?.isLoaded() ?? false
    }
    
    func load(song: Song) async throws {
        stop()
        print("AudioPlayer load")

        do {
            var realPitch: Double = 0.0
            if pitch != 0 {
                realPitch = Double(pitch)
            }
            engine = await song.isLocalMP3()
                ? MP3Engine()
                : try AppleMusicEngine()

            state = .loading
            try await engine!.load(song: song)

            if realPitch != 0 {
                    setPitch(pitch: realPitch)
            }
            
            syncFromEngine()
            startTicker()

        } catch (let error) {
            state = .failed
            throw error
        }
    }

    func play() async {
        print("AudioPlayer play")

        guard let engine else { return }
        try? await engine.play()
        syncFromEngine()
        startTicker()
    }

    func pause() {
        print("AudioPlayer pause")

        stopTicker()
        engine?.pause()
        syncFromEngine()
    }

    func stop() {
        print("AudioPlayer stop")

        stopTicker()
        engine?.stop()
        engine = nil
        state = .stopped
        position = 0
        syncFromEngine()
    }

    private func startTicker() {
        ticker?.cancel()
        ticker = Task {
            tickerStart = Date()
            positionSeconds = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(200))
                
                if let tickerStart {
                    let currentSeconds = Date.now.timeIntervalSince(tickerStart).rounded()
                    if positionSeconds != currentSeconds { positionSeconds = currentSeconds }
                }
                
                syncFromEngine()
            }
        }
    }

    private func stopTicker() {
        ticker?.cancel()
        positionSeconds = 0
        tickerStart = nil
    }
    
    private func syncFromEngine() {
        guard let engine else { return }
        duration = engine.duration
        position = engine.position
        rate = engine.rate
        pitch = engine.pitch
        state = engine.state
    }
    
    func setPosition(position: TimeInterval) {
        print("AudioPlayer setPosition")

        engine?.setPosition(position: position)
        syncFromEngine()
    }
    
    func setPitch(pitch: Double) {
        print("AudioPlayer setPitch")

        engine?.setPitch(pitch: pitch)
        syncFromEngine()
        
        // Hack für pitch, kann schon vorab ohne engine gesetzt werden
        if engine == nil {
            self.pitch = Float(pitch)
        }
    }
    
    func setRate(rate: Double) {
        print("AudioPlayer setRate")

        engine?.setRate(rate: rate)
        syncFromEngine()
    }
}

final class AppleMusicEngine: AudioEngine {
    private let player = ApplicationMusicPlayer.shared
    
    var duration: TimeInterval = 0
    var position: TimeInterval {
        get { player.playbackTime }
        set { player.playbackTime = newValue }
    }
    
    // Speed-Änderung started den Player, daher Status merken und restaurieren
    private var rate_: Float = 1.0
    var rate: Float { get {
        return rate_
    } set {
        rate_ = newValue
        let state = player.state.playbackStatus
        player.state.playbackRate = newValue
        restoreState(state: state)
    }}
        
    var pitch: Float = 0
    var state: PlayerState = .stopped
    
    private var musicAuthorizationStatus: MusicAuthorization.Status = .notDetermined

    init() async throws {
        try await handleAuthorizationStatus()
    }
    
    func isLoaded() -> Bool {
        !player.queue.entries.isEmpty
    }
    
    func load(song: Song) async throws {
        state = .loading
        
        let req = MusicCatalogResourceRequest<MusicKit.Song>(
            matching: \.id,
            equalTo: MusicItemID(song.musicItemId)
        )
        
        let res = try await req.response()
        guard let item = res.items.first else { throw PlayerError.notFound }
        
        duration = item.duration ?? 0
        player.queue = [item]
        
        let pl = player
        let pres = Task {
            try await pl.prepareToPlay()
        }
        let _ = try await pres.value
        
        state = .paused
    }
    
    func play() async throws {
        let pl = player
        let res = Task {
            try await pl.play()
            pl.state.playbackRate = self.rate
        }
        let _ = try await res.value
        
        state = .playing
    }
    
    func pause() {
        player.pause()
        state = .paused
    }
    
    func stop() {
        player.stop()
        state = .stopped
    }
    
    func setPosition(position: TimeInterval) {
        self.position = position
    }
    
    func setPitch(pitch: Double) {
    }
    
    func setRate(rate: Double) {
        self.rate = Float(rate)
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
            
        default:
            player.stop()
        }
    }
    
    func handleAuthorizationStatus() async throws {
        switch musicAuthorizationStatus {
        case .notDetermined:
            let musicAuthorizationStatus = await MusicAuthorization.request()
            update(with: musicAuthorizationStatus)
            
            if musicAuthorizationStatus != .authorized {
                throw PlayerError.noAppleMusic
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

final class MP3Engine: AudioEngine {
    private let engine = AVAudioEngine()
    private let node = AVAudioPlayerNode()
    private let pitchNode = AVAudioUnitTimePitch()
    private var file: AVAudioFile?
    private var sampleRate: Double = 44100 // Standard-Sample-Rate
    private var startTime: TimeInterval = 0

    var duration: TimeInterval = 0
    var position: TimeInterval { get { return getCurrentPosition() + startTime } set { seek(to: newValue) } }
    var rate: Float {
        get { pitchNode.rate }
        set { pitchNode.rate = newValue }
    }
    
    // range: -2400..2400
    // ein halbton = 100 Cents
    var pitch: Float {
        get { pitchNode.pitch / 10.0}
        set { pitchNode.pitch = newValue * 10.0;print(newValue * 10.0) }
    }
    var state: PlayerState = .stopped
    
    func isLoaded() -> Bool {
        engine.isRunning
    }
    
    func load(song: Song) async throws {
        let (urlStr, pitch) = try song.getMP3Info()
        
        let destDir = try GlobalFunctions.mp3Path()
        let filePath = destDir.appendingPathComponent(urlStr + ".mp3")
        
        state = .loading

        file = try AVAudioFile(forReading: filePath)
        
        if let file {
            sampleRate = file.processingFormat.sampleRate
            duration = Double(file.length) / sampleRate
            startTime = 0
            
            engine.attach(node)
            engine.attach(pitchNode)
            engine.connect(node, to: pitchNode, format: nil)
            engine.connect(pitchNode, to: engine.mainMixerNode, format: nil)
            
//            engine.attach(node)
//            engine.attach(pitchNode)
//            let mainMixer = engine.mainMixerNode
//            engine.connect(node, to: pitchNode, format: nil)
//            engine.connect(pitchNode, to: mainMixer, format: nil)
//            engine.connect(mainMixer, to: engine.outputNode, format: nil) // Mixer → Output
            
            #if os(iOS)
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                print("Fehler beim Setzen der Audio-Session: \(error)")
            }
            #endif
            
            self.pitch = pitch

            try engine.start()
            state = .paused
        } else {
            state = .failed
        }
    }

    func play() throws {
        guard let file else { return }

//        node.scheduleSegment(file, startingFrame: 0, frameCount: AVAudioFrameCount(file.length), at: nil, completionHandler: nil)
        node.scheduleFile(file, at: nil)

//        engine.mainMixerNode.outputVolume = 1.0
        node.play()
        state = .playing
    }

    func pause() {
        startTime = position
        node.pause()
        state = .paused
    }

    func stop() {
        startTime = 0
        node.stop()
        state = .stopped
    }
    
    func setPosition(position: TimeInterval) {
        self.position = position
    }
    
    func setPitch(pitch: Double) {
        self.pitch = Float(pitch)
    }
    
    func setRate(rate: Double) {
        self.rate = Float(rate)
    }
    
    private func seek(to seconds: TimeInterval) {
        guard let file = file else { return }
        
        let framePosition = AVAudioFramePosition(seconds * Double(sampleRate))
        let frameCount = AVAudioFrameCount(file.length - framePosition)
        
        if framePosition >= file.length {
            print("Seek-Zeit liegt außerhalb der Datei.")
            return
        }
        
        let isPlaying = node.isPlaying
                
        node.stop()
        node.scheduleSegment(file, startingFrame: framePosition, frameCount: frameCount, at: nil, completionHandler: nil)
        
        startTime = seconds
        
        if isPlaying { node.play() }
    }
    
    private func getCurrentPosition() -> TimeInterval {
        guard let lastRenderTime = node.lastRenderTime,
              let playerTime = node.playerTime(forNodeTime: lastRenderTime) else {
            return 0
        }
        
        guard sampleRate != 0 else { return 0 }
        return Double(playerTime.sampleTime) / Double(sampleRate)
    }
}
