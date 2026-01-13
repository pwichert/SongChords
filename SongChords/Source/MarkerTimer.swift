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
    private(set) var isRunning = false

    @ObservationIgnored
    private var task: Task<Void, Never>?

    func start() {
        guard !isRunning else { return }
        isRunning = true
        time = 0

        task = Task {
            let start = Date()
            while !Task.isCancelled {
                time = Date().timeIntervalSince(start)
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
