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
                // Lexer [Token] -> Parser [SongRenderChunk] -> Filter [SongRenderChunk] -> RepresentationHolder.rows [RowContent] -> DetailContent [RowView]
                //                                                                       -> RepresentationHolder.rowsForPrinting [RowContent] -> PrintSongDelegate [RowView]
                
//                let startTime = Date.now

                let lexer = ChordProLexer(input: srcText)
                let tokenStream = try await lexer.tokensAsStream()
                
                let parser = await ChordProParser(userSettings: userSettings.makeSendable(), songTranspose: transpose, forPrinting: forPrinting)
                let parserResult = await parser.chunksAsStream(tokens: tokenStream)     // liefert neben stream auch noch Taskresult mit dem DirectiveManagerSendable
                
                let chunkFilter = ViewFilter(userSettings: userSettings, showHeader: showHeader, showText: showText)
                let filteredStream = await chunkFilter.chunksAsStream(chunks: parserResult.stream)
                
                await self.representationHolder.reset()
                for try await chunk in filteredStream {
                    try Task.checkCancellation()
                    await self.representationHolder.append(chunk)
                }
                await self.representationHolder.isFinished()
                                
                let directiveManager = try await parserResult.directiveManager.value
                await self.representationHolder.setDirectiveManager(directiveManager)

//                print(Date.now.timeIntervalSince(startTime))

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
    private(set) var sections: [Int:SectionModel] = [:]

    @ObservationIgnored
    private var silentRows: [RowContent] = []
    
    @ObservationIgnored
    private var currentSectionId: Int?
    
    func append(_ chunks: [SongRenderChunk]) {
        // parser-token in entsprechenden event für RowContent umsetzen
        for chunk in chunks {
            let rowEvent: RowEvent? = switch chunk.content {
                case .newpage: .newpage
                case .columnbreak: .columnbreak
                default:  nil
            }
            
            if let secId = chunk.sectionId {
                currentSectionId = secId
                if sections[secId] == nil {
                    sections[secId] = SectionModel(id: secId)
                }
            }
            
            // row für DetailView hinzufügen
            let row = RowContent(sectionId: currentSectionId, chunkContent: chunk.content, rowEvent: rowEvent)
            silentRows.append(row)

            // Section suchen und row der Section-Struktur hinzufügen
            if let currentSectionId, let section = sections[currentSectionId] {
                section.rows.append(row)
                
                // Header-UUID der Section-Struktur hinzufügen
                if section.headerRowID == nil {
                    section.headerRowID = row.id
                }
            }
        }
    }
    
    func reset() {
        silentRows = []
        currentSectionId = nil
        sections = [:]
    }
    
    func resetRowContent() {
        rows = []
    }
    
    func isFinished() {
        if !silentRows.isEmpty {
            rows = silentRows
            silentRows = []
        }
    }
}

enum RowEvent {
    case newpage
    case columnbreak
}

final class RowContent: Identifiable {
    let id: UUID = UUID()
    let sectionId: Int?
    let chunkContent: SongRenderChunk.chunkContent
    let rowEvent: RowEvent?
    
    init(sectionId: Int?, chunkContent: SongRenderChunk.chunkContent, rowEvent: RowEvent? = nil) {
        self.chunkContent = chunkContent
        self.rowEvent = rowEvent
        self.sectionId = sectionId
    }
}

final class SectionModel: Identifiable {
    let id: Int          // die Parser-Section-ID
    var headerRowID: UUID?  // UUID der Header-Zeile
    var rows: [RowContent] = [] // zur Section zugehörige Rows

    init(id: Int) {
        self.id = id
    }
}
