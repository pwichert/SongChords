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

    #if true
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

            let lexer = await ChordProLexer(input: srcText)
            let tokenStream = try await lexer.tokensAsStream()
            let songRepresentation = try await ChordProParser(userSettings: userSettings, songTranspose: transpose, tokens: tokenStream, forPrinting: forPrinting).parse()

            return songRepresentation
        } catch is CancellationError {
//            print("createSongRepresentation cancelled")
            return nil
        } catch {
            print(error)
            return nil
        }
    }
    #else
    func processSongInBackground(representationHolder: RepresentationHolder, srcText: String, transpose: Int, userSettings: UserSettings) {
        processingTask?.cancel()
        
        processingTask = Task {
            do {
                representationHolder.reset()
                
                let lexer = ChordProLexerII(input: srcText)
                let tokenStream = try lexer.tokensAsStream()
                
                let parser = ChordProStreamingParser(
                    userSettings: userSettings,
                    songTranspose: transpose,
                    forPrinting: false
                )
                
                for try await token in tokenStream {
                    try Task.checkCancellation()
                    
                    if let chunk = try parser.consume(token) {
                        //                        print(chunk)
                        await MainActor.run {
                            representationHolder.append(chunk)
                        }
                    }
                }
                
                // letztes Fragment flushen
                let tail = parser.finish()
                await MainActor.run {
                    tail.forEach { representationHolder.append($0) }
                    representationHolder.renderChunks = representationHolder.renderChunks_
                }
            } catch is CancellationError {
                //            print("createSongRepresentation cancelled")
            } catch {
                print(error)
            }
        }
    }
    func createSongRepresentation(userSettings: UserSettings, srcText: String, transpose: Int, forPrinting: Bool) async -> SongRepresentation? {
        do {
            print("createSongRepresentation:", Thread.currentThread)

//            let tokens = try await ChordProLexer(input: srcText).tokenize()
//            try Task.checkCancellation()

            let lexer = ChordProLexerII(input: srcText)
            let tokenStream = try lexer.tokensAsStream()
            
            let songRepresentation = try await ChordProParser(userSettings: userSettings, songTranspose: transpose, tokens: tokenStream, forPrinting: forPrinting).parse()

            return songRepresentation
        } catch is CancellationError {
//            print("createSongRepresentation cancelled")
            return nil
        } catch {
            print(error)
            return nil
        }
    }

    #endif
}
