//
//  MarkerTimer.swift
//  SongChords
//
//  Created by Peter Wichert on 10.01.26.
//

import SwiftUI

@Observable
final class MarkerTimer {
    static let shared = MarkerTimer()
    
    private(set) var time: TimeInterval = 0

    @ObservationIgnored
    private var startTime: Date = Date()
    
    private(set) var isRunning = false

    @ObservationIgnored
    var exactTime: TimeInterval { get { isRunning ? Date().timeIntervalSince(startTime) : 0 }}

    @ObservationIgnored
    private var task: Task<Void, Never>?

    func start() {
        guard !isRunning else { return }
        isRunning = true
        time = 0

        task = Task {
            startTime = Date()
            while !Task.isCancelled {
                time = Date().timeIntervalSince(startTime)                
                try? await Task.sleep(for: .milliseconds(400)) // Auflösung
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        isRunning = false
    }
    
    deinit {
        task?.cancel()
        task = nil
    }
}
