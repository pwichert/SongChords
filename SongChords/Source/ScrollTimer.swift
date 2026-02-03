//
//  MarkerTimer.swift
//  SongChords
//
//  Created by Peter Wichert on 10.01.26.
//

import SwiftUI

enum TrackingMode {
    case audio
    case timer
    case none
}

@Observable
final class ScrollTimer {
    static let shared = ScrollTimer()
    
    // Zeit, die SwiftUI anzeigen soll
    private(set) var time: TimeInterval? // = 0

    private(set) var trackingMode: TrackingMode = .none

    // Playback rate (1.0 = normal)
    @ObservationIgnored
    private var rate: Double = 1.0

    // Exakte Zeit (nicht gedrosselt)
    @ObservationIgnored
    var exactTime: TimeInterval { Date().timeIntervalSince(startTime) * rate }

    @ObservationIgnored
    private var startTime = Date()

    @ObservationIgnored
    private var task: Task<Void, Never>?

    private init() { }

    // MARK: - Control

    func startTracking(_ trackingMode: TrackingMode) {
        self.trackingMode = trackingMode
        start()
    }
    
    func stopTracking() {
        self.trackingMode = .none
        stop()
    }
    
    private func start() {
        stop()

        startTime = Date()

        task = Task {
            while !Task.isCancelled {
                let t = Date().timeIntervalSince(startTime) * rate
                let newSecond = Int(floor(t))
                let uiSecond = Int((time ?? -1).rounded(.down))

                if uiSecond != newSecond {
                    time = TimeInterval(newSecond)
                }
                
                // tick 1x/sec, zur vollen Sekunde, sync mit Audio
                let nextTick = floor(t) + 1        // nächste volle Sekunde der Audio-Phase
                let sleep = max(0.001, nextTick - t)

                try? await Task.sleep(for: .seconds(sleep))
            }
        }
    }

    private func stop() {
        task?.cancel()
        task = nil
        time = nil
    }
    
    func syncToAudio(position: TimeInterval) {
        // phase lock: exactTime(now) == position
        startTime = Date().addingTimeInterval(-(position / rate))
    }
    
    // Change playback rate while keeping phase locked to audio
    func setRate(_ newRate: Double, audioPosition: TimeInterval) {
        guard newRate > 0 else { return }
        rate = newRate
        // keep clock aligned to current audio position
        startTime = Date().addingTimeInterval(-(audioPosition / rate))
    }
}
