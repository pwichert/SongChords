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
    private(set) var time: TimeInterval = 0

    private(set) var trackingMode: TrackingMode = .none

    // Exakte Zeit (nicht gedrosselt)
    @ObservationIgnored
    var exactTime: TimeInterval { get { Date().timeIntervalSince(startTime) }}

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
        time = 0
    }
    
    private func start() {
        stop()

        time = 0
        startTime = Date()

        task = Task {
            while !Task.isCancelled {
                time = Date().timeIntervalSince(self.startTime)
//                print("tick")
                try? await Task.sleep(for: .seconds(0.25))
            }
        }
    }

    private func stop() {
        task?.cancel()
        task = nil
    }
}
