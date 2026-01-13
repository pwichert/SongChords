//
//  TimerManager.swift
//  SongChords
//
//  Created by Peter Wichert on 28.01.25.
//

import SwiftUI

@Observable
class TimerManager {
    private var loopTimer: Timer? = nil
    private var isRunning: Bool = false

    /// Startet einen wiederholenden Timer mit einem bestimmten Intervall und einer auszuführenden Aufgabe.
    func startTimer(interval: TimeInterval, task: @escaping @Sendable () -> Void) async {
        // Falls der Timer läuft, zuerst stoppen
        await stopTimer()

        print("loopTimer started with interval \(interval) seconds.")
        self.isRunning = true

        self.loopTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            Task {
                task()
            }
        }
    }

    /// Setzt den Timer fort, falls er pausiert wurde.
    func resumeTimer(remainingInterval: TimeInterval, normalInterval: TimeInterval, task: @escaping @Sendable () -> Void) async {
        // Falls der Timer läuft, zuerst stoppen
        await stopTimer()

        print("Resuming loopTimer with \(remainingInterval) seconds remaining.")
        self.isRunning = true
        
        self.loopTimer = Timer.scheduledTimer(withTimeInterval: remainingInterval, repeats: false) { _ in
            task()
            print("loopTimer resumed and fired at \(Date.now)")
            Task { await self.startTimer(interval: normalInterval, task: task) }
        }
    }

    /// Stoppt den Timer und setzt den Zustand zurück.
    func stopTimer() async {
        guard isRunning else {
            print("loopTimer is not running.")
            return
        }

        self.loopTimer?.invalidate()
        self.loopTimer = nil
        self.isRunning = false
        print("loopTimer stopped.")
    }
}
