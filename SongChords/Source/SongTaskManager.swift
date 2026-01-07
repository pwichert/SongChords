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

final class SongTaskManager {
    static let shared = SongTaskManager()
    let manager = TaskManager()
    let representationHolder = RepresentationHolder()
    
    actor TaskManager {
        private var processingTask: Task<Void, Never>?
        
        func run(_ task: Task<Void, Never>) {
            cancel()
            processingTask = task
        }
        
        func cancel() {
            processingTask?.cancel()
            processingTask = nil
        }
        
        /// 🔑 WARTET, bis die aktuell laufende Task beendet ist
        func waitUntilFinished() async {
            await processingTask?.value
        }

        /// Optional: Status abfragen
        func isRunning() -> Bool {
            processingTask != nil
        }
    }
    
    func processSongInBackground(srcText: String, transpose: Int, showHeader: Bool, showText: Bool, userSettings: UserSettings, forPrinting: Bool = false) async {
        await manager.cancel()
        
        await manager.run(Task.detached {
            print("processSongInBackground:", Thread.currentThread)
            do {
                // Streaming-Pipeline:
                // Lexer [Token] -> Parser [SongRenderChunk] -> Filter [SongRenderChunk] -> RepresentationHolder.rows [RenderRowModel] -> DetailContent [RowView]
                
                let lexer = ChordProLexer(input: srcText)
                let tokenStream = try await lexer.tokensAsStream()
                
                let parser = await ChordProParser(userSettings: userSettings.makeSendable(), songTranspose: transpose, forPrinting: forPrinting)
                let chunkStream = await parser.chunksAsStream(tokens: tokenStream)
                
                let chunkFilter = ViewFilter(userSettings: userSettings, showHeader: showHeader, showText: showText)
                let filteredStream = await chunkFilter.chunksAsStream(chunks: chunkStream)
                
                await self.representationHolder.reset()
                for try await chunk in filteredStream {
                    try Task.checkCancellation()
                    await self.representationHolder.append(chunk)
                }
                await self.representationHolder.isFinished(forPrinting: forPrinting)
                
                await self.representationHolder.setDirectiveManager(parser.getDirectiveManager())
            } catch is CancellationError {
                print("processSongInBackground cancelled")
            } catch {
                print("error:", error)
            }
        })
    }
}

@Observable
class RepresentationHolder {
    @ObservationIgnored
    private(set) var directiveManager = DirectiveManagerSendable(directiveManager: DirectiveManager())
    
    func setDirectiveManager(_ directiveManager: DirectiveManagerSendable) {
        self.directiveManager = directiveManager
    }
    
    private(set) var rows: [RowContent] = []

    @ObservationIgnored
    private(set) var rowsForPrinting: [RowContent] = []

    @ObservationIgnored
    private(set) var silentRows: [RowContent] = []
    
    @ObservationIgnored
    private var rowID: Int = 0
    
    func append(_ chunks: [SongRenderChunk]) {
        // parser-token in entsprechenden event für RowContent umsetzen
        for chunk in chunks {
            let event: RowEvent? = switch chunk.content {
                case .newpage: .newpage
                case .columnbreak: .columnbreak
                default:  nil
            }
            
            silentRows.append(RowContent(id: rowID, content: chunk.content, event: event))
            rowID += 1
        }
    }
    
    func reset() {
        silentRows = []
    }
    
    func resetRowContent() {
        rows = []
    }
    
    func isFinished (forPrinting: Bool = false) {
        if !silentRows.isEmpty {
            if forPrinting { rowsForPrinting = silentRows } else { rows = silentRows }
            silentRows = []
        }
    }
}

enum RowEvent {
    case newpage
    case columnbreak
}

final class RowContent: Identifiable {
    let id: Int
    let content: SongRenderChunk.chunkContent
    let event: RowEvent?
    
    init(id: Int, content: SongRenderChunk.chunkContent, event: RowEvent? = nil) {
        self.id = id
        self.content = content
        self.event = event
    }
}
