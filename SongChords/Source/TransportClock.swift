//
//  TransportClock.swift
//  SongChords
//
//  Created by Peter Wichert on 04.02.26.
//

import SwiftUI

enum TransportMode {
    case audio
    case timer
    case none
}

@Observable
final class TransportClock {
    static let shared = TransportClock()

    private var task: Task<Void, Never>?

    private(set) var time: TimeInterval?
    
    var isRunningTimer: Bool { get { task != nil && transportMode == .timer }}
    var isRunningAudio: Bool { get { task != nil && transportMode == .audio }}

    private var transportMode: TransportMode = .none

    @ObservationIgnored
    var autoScrollEnabled: Bool = false
    
    // Callbacks
    @ObservationIgnored
    var audioTick: ((TimeInterval) -> TimeInterval?)?
    @ObservationIgnored
    private var scrollTick: ((TimeInterval) -> Void)?       // nicht benutzt. SongView triggert Autoscroll über .onChange(of: time)

    // Phase lock
    @ObservationIgnored
    private var startTime = ContinuousClock.now
    @ObservationIgnored
    private var startPosition: TimeInterval = 0
    @ObservationIgnored
    private var rate: Double = 1
    
    private func start() {
        print("Clock start")
        
        task?.cancel()
        task = nil
        
        startTime = ContinuousClock.now
        startPosition = 0.0
        rate = 1
        
        run()
    }
    
    private func run() {
        task = Task(priority: .utility) {
            while !Task.isCancelled {
                // 1️⃣ Audio-Tick. Synced die Position.
                let nextAudioEvent = transportMode == .audio ? audioTick?(position()) : nil
                if Task.isCancelled { break }

                // aktuelle, gesyncte Position
                let currentPosition = position()

                #if false
                if let time, autoScrollEnabled {
                    // 2️⃣ AutoScroll-Tick
                    scrollTick?(time)
                    if Task.isCancelled { break }

                    // Position aktualisieren
                    currentPosition = position()
                }
                #endif
                
//                print("tick \(currentPosition)")
                if time != currentPosition.rounded() { time = currentPosition.rounded() }

                // 3️⃣ Wann wieder aufwachen?
                let floor = floor(currentPosition)
                let nextFullSec: Double = currentPosition - floor < 0.75 ? floor + 1 : floor + 2    // x bis x.7499 -> x+1, sonst x+2
                                
                let nextWake = if let nextAudioEvent { min(nextAudioEvent, nextFullSec) } else { nextFullSec }
//                print("currentPosition \(currentPosition) nextFullSec \(nextFullSec) nextWake \(nextWake)")
                
                guard rate > 0.0 else { print("*** rate == 0"); break }
                let sleepSecs = max(0.001, nextWake - currentPosition) / rate
//                print("\(sleepSecs)")
                try? await Task.sleep(for: .seconds(sleepSecs), tolerance: .milliseconds(5))
            }
        }
    }
    
    private func stop() {
        print("Clock stop")
        task?.cancel()
        task = nil
        time = nil
    }

    func startTicker(_ transportMode: TransportMode) {
        self.transportMode = transportMode
        start()
    }
    
    func stopTicker() {
        stop()
        self.transportMode = .none
    }
    
    // für sofortige UI-Reaktion sleep abbrechen
    func restartTicker() {
        guard task != nil else { return }
        print("Clock restart")
        task?.cancel()
        task = nil
        run()
    }
    
    private func position() -> TimeInterval {
        let d = startTime.duration(to: ContinuousClock.now)
        let c = d.components
        let el = Double(c.seconds) + Double(c.attoseconds) * 1e-18
        return startPosition + el * rate
    }

    func sync(_ position: TimeInterval, rate: Float = 1.0) {
        self.rate = Double(rate)
        startTime = .now
        startPosition = position
//        print("sync to \(position) at rate \(self.rate)")
    }
}
