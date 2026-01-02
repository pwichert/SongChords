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
    private(set) var processingTask: Task<Void, Never>?
    static let shared = SongTaskManager()

    #if false
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
    func processSongInBackground(representationHolder: RepresentationHolder, srcText: String, transpose: Int, showHeader: Bool, showText: Bool, userSettings: UserSettings, forPrinting: Bool = false) {
        processingTask?.cancel()
        print("processSongInBackground")
        
        processingTask = Task {
            do {
                representationHolder.reset()
                representationHolder.directiveManager = DirectiveManager()
                
                // Streaming-Pipeline:
                // Lexer [Token] -> Parser [SongRenderChunk] -> Filter [SongRenderChunk] -> RepresentationHolder.rows [RenderRowModel] -> DetailContent [RowView]
                
                let lexer = ChordProLexer(input: srcText)
                let tokenStream = try lexer.tokensAsStream()
                
                let parser = ChordProParserII(directiveManager: representationHolder.directiveManager, userSettings: userSettings, songTranspose: transpose, forPrinting: forPrinting)
                let chunkStream = parser.chunksAsStream(tokens: tokenStream)

                let chunkFilter = ViewFilter(userSettings: userSettings, showHeader: showHeader, showText: showText)
                let filteredStream = chunkFilter.chunksAsStream(chunks: chunkStream)
                
                for try await chunk in filteredStream {
                    try Task.checkCancellation()
                    representationHolder.append(chunk)
                }
                representationHolder.update()
                
            } catch is CancellationError {
                print("processSongInBackground cancelled")
            } catch {
                print("error:", error)
            }
        }
    }
    
    func createSongRepresentation_(userSettings: UserSettings, srcText: String, transpose: Int, forPrinting: Bool) async -> SongRepresentation? {
        do {
            print("createSongRepresentation:", Thread.currentThread)

//            let tokens = try await ChordProLexer(input: srcText).tokenize()
//            try Task.checkCancellation()

            let lexer = ChordProLexer(input: srcText)
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
