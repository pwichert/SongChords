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
    case noAppleMusicSubscription
    case invalidLoop
    
    var errorDescription: String? {
        switch self {
        case .notFound: return String(localized: "not found")
        case .invalidMP3Info: return String(localized: "invalid MP3 info")
        case .noAppleMusic: return String(localized: "no Apple Music")
        case .noAppleMusicSubscription: return String(localized: "no Apple Music Subscription")
        case .invalidLoop: return String(localized: "invalid Loop")
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

@Observable
final class TransportState {
    var duration: TimeInterval = 0
    var position: TimeInterval = 0
    var rate: Float = 1
    var pitch: Float = 0
    var state: PlayerState = .stopped
    var loop: PlayerLoop?
}

protocol AudioEngine {
    var duration: TimeInterval { get }
    var position: TimeInterval { get set }
    var rate: Float { get set }
    var pitch: Float { get set }
    
    func load(song: Song) async throws
    func play() async throws
    func pause()
    func stop()
    func isLoaded() -> Bool
}

@Observable
final class AudioPlayer {
    private var transport = TransportState()
        
    @ObservationIgnored
    private var engine: AudioEngine?

    private(set) var state: PlayerState { get { transport.state } set { transport.state = newValue }}
    private(set) var duration: TimeInterval { get { transport.duration } set { transport.duration = newValue }}
    
    var loop: PlayerLoop? { get { return transport.loop } set { transport.loop = newValue }}

    var position: TimeInterval {
        get {
            if tickerEnd > 0 && transport.position >= tickerEnd { stop() }
            return transport.position
        }
        set {
            print("position = \(newValue)")
            transport.position = newValue
            engine?.position = newValue
        }}
    
    var rate: Float { get { transport.rate }
        set {
            print("rate = \(newValue)")
            transport.rate = newValue
            engine?.rate = newValue
        }}
    
    var pitch: Float { get { transport.pitch }
        set {
            print("pitch = \(newValue)")
            transport.pitch = newValue
            engine?.pitch = newValue
        }}

    @ObservationIgnored
    private var ticker: Task<Void, Never>?
    static let tickerSleepMilliSeconds: Int = 200
    static let tickerBuffer = TimeInterval((Double(tickerSleepMilliSeconds) * 1.5) / 1000.0)

    @ObservationIgnored
    var tickerEnd: TimeInterval { max(0, duration - AudioPlayer.tickerBuffer) }
    
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
            let newEngine: AudioEngine = await song.isLocalMP3()
                ? MP3Engine()
                : try AppleMusicEngine()

            state = .loading
            try await newEngine.load(song: song)

            engine = newEngine
            
            duration = engine?.duration ?? 0
            applyTransportToEngine()
            startTicker()

        } catch (let error) {
            state = .failed
            throw error
        }
    }

    func play() async throws {
        print("AudioPlayer play")

        startTicker()
        try await engine?.play()
        state = .playing
    }

    func pause() {
        print("AudioPlayer pause")

        stopTicker()
        engine?.pause()
        state = .paused
    }

    func stop() {
        print("AudioPlayer stop")

        stopTicker()
        engine?.stop()
        engine = nil
        position = 0
        state = .stopped
    }

    private func startTicker() {
        stopTicker()

        ticker = Task {
            while !Task.isCancelled {
                guard var e = engine else { return }
                let currentPosition = e.position

                if let l = loop, l.start < l.stop, currentPosition < max(l.start, 0) || currentPosition >= min(l.stop, tickerEnd) {
//                    print("korrigiert von \(currentPosition) auf \(max(l.start, 0))")
                    e.position = max(l.start, 0)
                }
                
                transport.position = e.position
//                print("\(position) : \(duration)")
                
                try? await Task.sleep(for: .milliseconds(AudioPlayer.tickerSleepMilliSeconds))
            }
        }
    }
    
    private func stopTicker() {
        ticker?.cancel()
        ticker = nil
    }
    
    private func applyTransportToEngine() {
        if engine != nil {
            if engine?.rate != rate { engine?.rate = rate }
            if engine?.pitch != pitch  { engine?.pitch = pitch }
            if engine?.position != position { engine?.position = position }
        }
        
        self.loop = loop

        if state == .playing {
            Task { try? await engine?.play() }
        }
    }
    
    func setDefaults() {
        transport = TransportState()
    }
}

final class AppleMusicEngine: AudioEngine {
    private let player = ApplicationMusicPlayer.shared
    
    var duration: TimeInterval = 0
    var position: TimeInterval {
        get {
            if duration > 0 && player.playbackTime >= duration {
                print("Playback beendet.")
                self.stop()
                player.playbackTime = 0
            }
            return player.playbackTime
        }
        set {
            player.playbackTime = newValue }
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
    
    private var musicAuthorizationStatus: MusicAuthorization.Status = .notDetermined

    init() async throws {
        try await handleAuthorizationStatus()
    }
    
    func isLoaded() -> Bool {
        !player.queue.entries.isEmpty
    }
    
    func load(song: Song) async throws {
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
    }
    
    func play() async throws {
        let pl = player
        let res = Task {
            try await pl.play()
            pl.state.playbackRate = self.rate
        }
        let _ = try await res.value
    }
    
    func pause() {
        player.pause()
    }
    
    func stop() {
        player.stop()
    }
    
    private func restoreState(state: MusicKit.MusicPlayer.PlaybackStatus) {
        print("Audioplayer restoring \(state)")
        switch state {
        case .playing:
            // setzen der Rate started immer das playing, daher hier nicht nochmal
            break
            
        case .paused:
            player.pause()
            
        default:
            player.stop()
        }
    }
    
    private func handleAuthorizationStatus() async throws {
        let auth = await MusicAuthorization.request()
        guard auth == .authorized else { throw PlayerError.noAppleMusic }
        
        let subscription = try await MusicSubscription.current
        guard subscription.canPlayCatalogContent else { throw PlayerError.noAppleMusicSubscription }
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
        set { pitchNode.pitch = newValue * 10.0 }
    }
    
    func isLoaded() -> Bool {
        engine.isRunning
    }
    
    func load(song: Song) async throws {
        let (urlStr, pitch) = try song.getMP3Info()
        
        let destDir = try GlobalFunctions.mp3Path()
        let filePath = destDir.appendingPathComponent(urlStr + ".mp3")
        
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
        }
    }

    func play() throws {
        guard let file else { return }

//        node.scheduleSegment(file, startingFrame: 0, frameCount: AVAudioFrameCount(file.length), at: nil, completionHandler: nil)
        node.scheduleFile(file, at: nil)

//        engine.mainMixerNode.outputVolume = 1.0
        node.play()
    }

    func pause() {
        startTime = position
        node.pause()
    }

    func stop() {
        startTime = 0
        node.stop()
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
        
        let res = Double(playerTime.sampleTime) / Double(sampleRate)
        
        if res + startTime >= duration {
            print("Playback beendet.")
            self.stop()
            seek(to: 0)
        }
        
        guard sampleRate != 0 else { return 0 }
        return Double(playerTime.sampleTime) / Double(sampleRate)
    }
}
