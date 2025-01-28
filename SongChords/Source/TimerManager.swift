//
//  TimerManager.swift
//  SongChords
//
//  Created by Peter Wichert on 28.01.25.
//

import SwiftUI

// TimerManagerWrapper, damit TimerManager @Observable wird und
// als @State var initialisiert werden kann.
@Observable
final class TimerManagerWrapper: Sendable {
    let timerManager: TimerManager = TimerManager()
}

actor TimerManager {
    private var loopTimer: Timer? = nil
    private var startTime: Date = .now
    private var remaining: TimeInterval = 0
    private var interval: TimeInterval = 0
    private var isRunning: Bool = false

    /// Startet einen wiederholenden Timer mit einem bestimmten Intervall und einer auszuführenden Aufgabe.
    func startTimer(interval: TimeInterval, task: @escaping @Sendable () -> Void) {
        // Falls der Timer läuft, zuerst stoppen
        stopTimer()

        print("loopTimer started with interval \(interval) seconds.")
        self.interval = interval
        self.startTime = .now
        self.remaining = interval
        self.isRunning = true

        // Erstelle den Timer im Main Thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            Task {
                await setTimer(timer: Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
                    Task {
                        await self.nextRun()
                        task()
                        print("loopTimer fired at \(Date.now)")
                    }
                })
            }
        }
    }

    private func setTimer(timer: Timer) {
        self.loopTimer = timer
    }
    
    private func nextRun() {
        startTime = .now
    }
    
    /// Pausiert den Timer und speichert die verbleibende Zeit.
    func pauseTimer() {
        guard isRunning else {
            print("loopTimer is not running.")
            return
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            Task { @MainActor in await setPause() }
        }
    }
    
    private func setPause() {
        if let loopTimer = self.loopTimer {
            self.remaining = self.interval - Date.now.timeIntervalSince(self.startTime)
            loopTimer.invalidate()
            self.loopTimer = nil
            self.isRunning = false
            print("loopTimer paused with \(self.remaining) seconds remaining.")
        }
    }

    /// Setzt den Timer fort, falls er pausiert wurde.
    func resumeTimer(task: @escaping @Sendable () -> Void) {
        guard !isRunning, remaining > 0 else {
            print("loopTimer is already running or has no remaining time.")
            return
        }

        print("Resuming loopTimer with \(remaining) seconds remaining.")
        self.startTime = .now
        self.isRunning = true

        // Erstelle den Timer im Main Thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            Task {
                await setTimer(timer: Timer.scheduledTimer(withTimeInterval: self.remaining, repeats: false) { _ in
                    task()
                    print("loopTimer resumed and fired at \(Date.now)")
                    Task { await self.startTimer(interval: self.interval, task: task) }
                })
            }
        }
    }

    /// Stoppt den Timer und setzt den Zustand zurück.
    func stopTimer() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            Task { @MainActor in await self.setStop() }
            print("loopTimer stopped.")
        }
    }
    
    private func setStop() {
        self.loopTimer?.invalidate()
        self.loopTimer = nil
        self.remaining = 0
        self.isRunning = false
    }
}
