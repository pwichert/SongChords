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

    @ObservationIgnored
    private var task: Task<Void, Never>?

    private(set) var time: TimeInterval?
    
    var isRunningTimer: Bool { get { task != nil && transportMode == .timer }}
    var isRunningAudio: Bool { get { task != nil && transportMode == .audio }}

    @ObservationIgnored
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
    private var startTime = Date.now
    @ObservationIgnored
    private var startPosition: TimeInterval = 0
    @ObservationIgnored
    private var rate: Double = 1
    
    private func start() {
        print("Clock start")

        task?.cancel()
        task = nil
        
        startTime = Date.now
        startPosition = 0.0
        rate = 1

        task = Task(priority: .utility) {
            while !Task.isCancelled {
                // 1️⃣ Audio-Tick. Synced die Position.
                let nextAudioEvent = transportMode == .audio ? audioTick?(position()) : nil

                // aktuelle, gesyncte Position
                var currentPosition = position()
//                print("tick \(currentPosition)")
                
                if time != currentPosition.rounded() { time = currentPosition.rounded() }

                #if false
                if let time, autoScrollEnabled {
                    // 2️⃣ AutoScroll-Tick
                    scrollTick?(time)

                    // Position aktualisieren
                    currentPosition = position()
                }
                #endif
                
                // 3️⃣ Wann wieder aufwachen?
                let nextWake = min(nextAudioEvent ?? 100000.0, currentPosition.rounded() + 1)
                guard rate > 0.0 else { break }
                let sleepSecs = max(0.001, nextWake - currentPosition) / rate
                
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
    
    private func position() -> TimeInterval {
        let el = Date.now.timeIntervalSince(startTime)
        return startPosition + el * rate
    }

    func sync(_ position: TimeInterval, rate: Float = 1.0) {
        self.rate = Double(rate)
        startTime = .now
        startPosition = position
//        print("sync to \(position) at rate \(self.rate)")
    }
}
