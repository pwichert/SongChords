//
//  SongTaskManager.swift
//  SongChords
//
//  Created by Peter Wichert on 10.02.25.
//

import Foundation

extension Thread {
    nonisolated static var currentThread: Thread {
        return Thread.current
    }
}

@MainActor
class SongTaskManager {
    private var processingTask: Task<Void, Never>?
    static let shared = SongTaskManager()

    func processSongInBackground(representationHolder: RepresentationHolder, srcText: String, transpose: Int, userSettings: UserSettings) {
        processingTask?.cancel()

        processingTask = Task {
            let result = await createSongRepresentation(userSettings: userSettings, srcText: srcText, transpose: transpose, forPrinting: false)

            guard !Task.isCancelled, let result else { return }

            representationHolder.updateSongRepresentation(result)
        }
    }

    @concurrent
    func createSongRepresentation(userSettings: UserSettings, srcText: String, transpose: Int, forPrinting: Bool) async -> SongRepresentation? {
        do {
            print("createSongRepresentation:", Thread.currentThread)

            let tokens = try await ChordProLexer(input: srcText).tokenize()
            try Task.checkCancellation()

            let songRepresentation = try await ChordProParser(userSettings: userSettings, songTranspose: transpose, tokens: tokens, forPrinting: forPrinting).parse()
            try Task.checkCancellation()

            return songRepresentation
        } catch is CancellationError {
//            print("createSongRepresentation cancelled")
            return nil
        } catch {
            print(error)
            return nil
        }
    }
}
