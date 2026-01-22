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
import SwiftData

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
    var isPlaying: Bool { get }
    var isLoaded: Bool { get }

    func load(song: Song) async throws
    func play() async throws
    func pause()
    func stop()
}

@Observable
final class AudioPlayer {
    private var transport = TransportState()
        
    private let tickerSleepInterval: TimeInterval = 0.2
    
    @ObservationIgnored
    private var engine: AudioEngine?
    
    var isLoaded: Bool { get { engine?.isLoaded ?? false }}

    private(set) var state: PlayerState { get { transport.state } set { transport.state = newValue }}
    private(set) var duration: TimeInterval { get { transport.duration } set { transport.duration = newValue }}
    var loop: PlayerLoop? { get { return transport.loop } set { transport.loop = newValue }}

    var position: TimeInterval {
        get {
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
    
    isolated
    deinit {
        print("AudioPlayer deinit")
        stop()
    }
    
    
    func load(song: Song) async throws {
        print("AudioPlayer load")
        stopTicker()
        engine?.stop()
        engine = nil

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

        try await engine?.play()
        state = .playing
        startTicker()
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

                // loop evtl wieder auf anfang
                if let l = loop, isValidLoop(loop: l), currentPosition < max(l.start, 0) || currentPosition >= min(l.stop, duration) {
//                    print("korrigiert von \(currentPosition) auf \(max(l.start, 0))")
                    e.position = max(l.start, 0)
                }

                // engine.position zurückmelden
                transport.position = e.position
//                print("\(position) : \(duration)")
                
                // üblicherweise am ende
                if !e.isPlaying {
                    print("engine stopped")
                    stop()
                    return
                }
                
                try? await Task.sleep(for: .seconds(tickerSleepInterval))
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
    
    func isValidLoop(loop: PlayerLoop) -> Bool {
        let maxLoopStop = max(0, duration - 2.5 * tickerSleepInterval)
        let minLoopDuration = 2.5 * tickerSleepInterval
        return loop.stop > 0.0 && loop.stop < maxLoopStop && loop.start < loop.stop && loop.stop - loop.start > minLoopDuration
    }
}

actor MusicItemCache {
    typealias MusicID = String

    struct Entry {
        let value: MusicKit.Song?
        let insertedAt: Date
    }

    private var store: [MusicID: Entry] = [:]

    private let ttl: TimeInterval
    private let maxEntries: Int?
    private var lastCleanup: Date
    
    init(ttl: TimeInterval = 60 * 60 * 4, maxEntries: Int? = 200) {
        self.ttl = ttl
        self.maxEntries = maxEntries
        self.lastCleanup = .now
    }

    // Doppelt-Optional: nil = miss, .some(nil) = negativ gecacht, .some(.some(song)) = hit
    func get(_ id: MusicID) -> MusicKit.Song?? {
        cleanupIfNeeded()

        guard let entry = store[id] else { return nil } // miss

        if Date().timeIntervalSince(entry.insertedAt) > ttl {
            store[id] = nil
            return nil // miss (abgelaufen)
        }

        return .some(entry.value) // hit (value kann nil sein)
    }

    func set(_ id: MusicID, value: MusicKit.Song?) {
        store[id] = Entry(value: value, insertedAt: Date.now)
        enforceLimit()
    }

    // MARK: - Intern

    private func cleanupIfNeeded() {
        guard Date().timeIntervalSince(lastCleanup) > 60 * 10 else { return }

        lastCleanup = .now
        store = store.filter { Date().timeIntervalSince($0.value.insertedAt) <= ttl }
    }

    private func enforceLimit() {
        guard let max = maxEntries, store.count > max else { return }

        // Einfaches LRU-Light: älteste zuerst raus
        let overflow = store.count - max
        let sorted = store.sorted { $0.value.insertedAt < $1.value.insertedAt }
        for i in 0..<overflow {
            store[sorted[i].key] = nil
        }
    }
}

final class AppleMusicEngine: AudioEngine {
    private let player = ApplicationMusicPlayer.shared
    
    private var aboutToPlay: Bool = false
    private var loaded: Bool = false
    
    var isPlaying: Bool { get { return aboutToPlay || player.state.playbackStatus == .playing }}
    var isLoaded: Bool { get { loaded }}
    var duration: TimeInterval = 0
    var position: TimeInterval {
        get { return player.playbackTime }
        set { player.playbackTime = newValue }}
    
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
    private static let sharedMusicItemCache = MusicItemCache()
    
    init() async throws {
        try await handleAuthorizationStatus()
    }
    
    func load(song: Song) async throws {
        loaded = false
        
        var item: MusicItemCollection<MusicKit.Song>.Element?
        
        let key = song.musicItemId
        switch await AppleMusicEngine.sharedMusicItemCache.get(key) {
        case .some(let value):
            item = value   // kann nil oder Song sein
            print("AppleMusicEngine cache")

        case .none:
            let req = MusicCatalogResourceRequest<MusicKit.Song>(
                matching: \.id,
                equalTo: MusicItemID(song.musicItemId)
            )
            
            let res = try await req.response()
            let fetched = res.items.first
            await AppleMusicEngine.sharedMusicItemCache.set(key, value: fetched)
            item = fetched
        }
        
        guard let item = item else { throw PlayerError.notFound }
        
        duration = item.duration ?? 0
        player.queue = [item]
        
        let pl = player
        let pres = Task {
            try await pl.prepareToPlay()
        }
        let _ = try await pres.value
        loaded = true
    }
    
    func play() async throws {
        let pl = player
        
        // nach .play() ist der Zustand erst .pause, nicht .playing
        // aboutToPlay überbrückt bis .playing
        aboutToPlay = true
        
        let res = Task {
            try await pl.play()
            pl.state.playbackRate = self.rate
        }
        let _ = try await res.value
        
        aboutToPlay = false
    }
    
    func pause() {
        player.pause()
    }
    
    func stop() {
        player.stop()
        loaded = false
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
    private var loaded: Bool = false

    var isPlaying: Bool { get { return isInside() && node.isPlaying }}
    var isLoaded: Bool { get { loaded }}
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
    
    func load(song: Song) throws {
        loaded = false
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

            engine.prepare()
            node.scheduleFile(file, at: nil)
            
            startTime = 0
            loaded = true
        }
    }

    func play() throws {
        try engine.start()
        node.play()
    }

    func pause() {
        node.pause()
        engine.pause()
    }

    func stop() {
        node.stop()
        engine.stop()
        loaded = false
    }
    
    private func seek(to seconds: TimeInterval) {
        guard let file else { return }
        
        let framePosition = min(AVAudioFramePosition(seconds * Double(sampleRate)), file.length - 1)
        let frameCount = AVAudioFrameCount(file.length - framePosition)
        
        if framePosition >= file.length {
            print("Seek-Zeit liegt außerhalb der Datei. \(framePosition) >= \(file.length)")
            return
        }
        
        let isPlaying = node.isPlaying
                
        node.stop()
        node.scheduleSegment(file, startingFrame: framePosition, frameCount: frameCount, at: nil, completionHandler: nil)
        
        startTime = seconds
        
        if isPlaying { node.play() }
    }
    
    private func isInside() -> Bool {
        guard let lastRenderTime = node.lastRenderTime,
              let playerTime = node.playerTime(forNodeTime: lastRenderTime) else {
            return false
        }
        
        let res = Double(playerTime.sampleTime) / Double(sampleRate)
        return res + startTime < duration
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

