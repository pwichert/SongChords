//
//  TimerManager.swift
//  SongChords
//
//  Created by Peter Wichert on 28.01.25.
//

import SwiftUI

// für @State var
@Observable
@MainActor
final class TimerManagerWrapper: Sendable {
    let timerManager: TimerManager = TimerManager()
}

@MainActor
class TimerManager {
    private var loopTimer: Timer? = nil
    private var startTime: Date = .now
    private var remaining: TimeInterval = 0
    private var interval: TimeInterval = 0
    private var isRunning: Bool = false

    /// Startet einen wiederholenden Timer mit einem bestimmten Intervall und einer auszuführenden Aufgabe.
    func startTimer(interval: TimeInterval, task: @escaping @Sendable () -> Void) async {
        // Falls der Timer läuft, zuerst stoppen
        await stopTimer()

        print("loopTimer started with interval \(interval) seconds.")
        self.interval = interval
        self.startTime = .now
        self.remaining = interval
        self.isRunning = true

        await self.setTimer(timer: Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            Task {
                await self.nextRun()
                task()
            }
        })
    }

    private func setTimer(timer: Timer) async {
        self.loopTimer = timer
    }
    
    private func nextRun() async {
        startTime = .now
    }
    
    /// Pausiert den Timer und speichert die verbleibende Zeit.
    func pauseTimer() {
        guard isRunning else {
            print("loopTimer is not running.")
            return
        }

        if let loopTimer = self.loopTimer {
            self.remaining = self.interval - Date.now.timeIntervalSince(self.startTime)
            loopTimer.invalidate()
            self.loopTimer = nil
            self.isRunning = false
            print("loopTimer paused with \(self.remaining) seconds remaining.")
        }
    }

    /// Setzt den Timer fort, falls er pausiert wurde.
    func resumeTimer(task: @escaping @Sendable () -> Void) async {
        guard !isRunning, remaining > 0 else {
            print("loopTimer is already running or has no remaining time.")
            return
        }

        print("Resuming loopTimer with \(remaining) seconds remaining.")
        self.startTime = .now
        self.isRunning = true
        
        await setTimer(timer: Timer.scheduledTimer(withTimeInterval: self.remaining, repeats: false) { _ in
            task()
            print("loopTimer resumed and fired at \(Date.now)")
            Task { await self.startTimer(interval: self.interval, task: task) }
        })
    }

    /// Stoppt den Timer und setzt den Zustand zurück.
    func stopTimer() async {
        guard isRunning else {
            print("loopTimer is not running.")
            return
        }

        self.loopTimer?.invalidate()
        self.loopTimer = nil
        self.remaining = 0
        self.isRunning = false
        print("loopTimer stopped.")
    }
}
