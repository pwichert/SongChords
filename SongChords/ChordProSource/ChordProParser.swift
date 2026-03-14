//
//  Song.swift
//  SongChords Develop
//
//  Created by Peter Wichert on 09.10.24.
//

import SwiftUI

#if os(macOS)
    typealias UIFont = NSFont
#endif

nonisolated
public struct SplittedLine: Identifiable {
    public let id = UUID()
    
    var chords: [TextElement] = []
    var texts: [TextElement] = []
    var plainText: String = ""
    
    var onNewPage: Bool = false
    var col: Int = 0
    
    func textsIsWhithespaceOrEmpty() -> Bool {
        if texts.isEmpty { return true }
        return texts.allSatisfy { $0.txt.trimmingCharacters(in: .whitespaces).isEmpty }
    }
    
    func textsToString() -> String? {
        if texts.isEmpty { return nil }
        
        var res: String = ""
        
        for txt in texts {
            let pos = Int(txt.fontOffset)
            if res.count < pos {
                res.append(String(repeating: " ", count: pos - res.count))
            }
            res.append(txt.txt)
        }
        
        return res
    }
    
    func toString() -> String {
        var res: String = "[np:\(onNewPage)][col:\(col)]"
        res += chords.map( { $0.toString() + " " } ).joined()
        res += "|| "
        res += texts.map( { $0.toString() + " " } ).joined()
        return res
    }
}

nonisolated
public struct TextElement: Sendable, Identifiable, Equatable {
    public let id = UUID()
    let txt: String
    let isChordcomment: Bool    // merken, da "*" in txt schon entfernt ist
    let fontOffset: Double
    let background: Bool
    
    let chord: Chord?     // falls dieser Text ein Chord ist, für diagrammerzeugung merken
    
    func toString() -> String {
        return ("[\(Int(fontOffset))]\(txt)")
    }
    
    func isWhiteSpace() -> Bool {
        return txt.trimmingCharacters(in: .whitespaces).isEmpty
    }
}

/// Ein inkrementell darstellbares Render-Fragment (z. B. eine fertige Zeile)
nonisolated
public struct SongRenderChunk: Sendable, Identifiable {
    public let id: UUID = UUID()
    public let sectionId: Int?
    public let content: chunkContent
    
    init(content: chunkContent) {
        self.content = content
        
        if case .sectionStarted( _, let sectionId) = content {
            self.sectionId = sectionId
        } else { self.sectionId = nil }
    }
    
    public func toChordProString() -> String {
        var res = ""
        
        switch content {
            
        case .sectionStarted(let section, _):
            res += "[" + section + "]"
                        
        case .chordline(let chords):
            res += chords.map { $0.txt }.joined(separator: " ")
            
        case .textline(_, plaintext: let plaintext):
            res += plaintext
            
        case .splittedline(chords: let chords, texts: let texts, plaintext: _):
            res += chords.map { $0.txt }.joined(separator: " ") + "\n"
            res += texts.map { $0.txt }.joined(separator: " ")

        case .emptyline:
            res += "\n"
            
        default:
            return ""
        }
        
        return res + "\n"
    }
    
    public enum chunkContent: Sendable, Equatable {
        case sectionStarted(String, Int)
        case sectionEnded
        case chordline([TextElement])
        case textline([TextElement], plaintext: String)
        case splittedline(chords: [TextElement], texts: [TextElement], plaintext: String)
        case chordplainline([TextElement])
        case textplainline(String)
        case emptyline
        case newpage
        case columnbreak
        
        func toString() -> String {
            switch self {
            case .sectionStarted(let str, let sectionId):
                return "sectionStarted \(str) \(sectionId)"
                
            case .sectionEnded:
                return "sectionEnded"
                
            case .chordline:
                return "chordline"
                
            case .textline:
                return "textline"
                
            case .splittedline:
                return "splittedline"
                
            case .chordplainline:
                return "chordplainline"
                
            case .textplainline:
                return "textplainline"
                
            case .emptyline:
                return "emptyline"
                
            case .newpage:
                return "newpage"
                
            case .columnbreak:
                return "columnbreak"
            }
        }
    }
}

nonisolated
public class ViewFilter {
    let userSettings: UserSettings
    let showHeader: Bool
    let showText: Bool
    
    public init(userSettings: UserSettings, showHeader: Bool, showText: Bool) {
        self.userSettings = userSettings
        self.showHeader = showHeader
        self.showText = showText
    }
    
    @concurrent
    public func chunksAsStream(chunks: AsyncThrowingStream<[SongRenderChunk], Error>) async -> AsyncThrowingStream<[SongRenderChunk], Error> {
        AsyncThrowingStream { continuation in
            continuation.onTermination = { termination in
//                                print("chunk stream terminated:", termination)
            }
            
            let showText = self.showText
            let showHeader = self.showHeader
            let userSettings = self.userSettings
            
            Task {
//                print("viewfilter: chunksAsStream:", Thread.currentThread)

                do {
                    let hideChords = await userSettings.hidechords
                    
                    for try await chunk in chunks {
                        try Task.checkCancellation()
                            
                        var res: [SongRenderChunk] = []
                        for c in chunk {
                            switch c.content {
                                
                            case .sectionStarted(let section, let sectionId):
                                if showHeader && section.trimmingCharacters(in: .whitespaces).count > 0 {
                                    res.append(SongRenderChunk(content: .sectionStarted(section, sectionId)))
                                }
                                
                            case .chordline(let chords):
                                if !hideChords {
                                    if showText {
                                        res.append(SongRenderChunk(content: .chordline(chords)))
                                    } else {
                                        res.append(SongRenderChunk(content: .chordplainline(chords)))
                                    }
                                }

                            case .textline(let texts, let plaintext):
                                if showText {
                                    if !hideChords {
                                        res.append(SongRenderChunk(content: .textline(texts, plaintext: plaintext)))
                                    } else {
                                        res.append(SongRenderChunk(content: .textplainline(plaintext)))
                                    }
                                }
                                
                            case .splittedline(chords: let chords, texts: _, let plaintext):
                                // chords und texts sind gefüllt
                                if hideChords {
                                    if showText { res.append(SongRenderChunk(content: .textplainline(plaintext))) }
                                } else {
                                    if showText {
                                        res.append(SongRenderChunk(content: c.content))
                                    } else {
                                        res.append(SongRenderChunk(content: .chordplainline(chords)))
                                    }
                                }

                            case .sectionEnded:
                                // keine View zur Darstellung benötigt und trägt auch keine Funktionen, wird nicht weitergereicht
                                break
                                
                            default:
                                res.append(SongRenderChunk(content: c.content))
                            }
                        }
                        continuation.yield(res)
                    }
                    
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

nonisolated
internal class ParserHelper {
    static func allWhitespace(elements: [TextElement]) -> Bool {
        return elements.allSatisfy { $0.txt.trimmingCharacters(in: .whitespaces).isEmpty }
    }
}

public struct ParserResult {
    public let stream: AsyncThrowingStream<[SongRenderChunk], Error>
    let directiveManager: Task<DirectiveManagerSendable, Error>
}

enum CacheResult<T> {
    case miss
    case hit(T?)
}

nonisolated
struct ChordCacheKey: Sendable, Hashable {
    let chord: String
    let rootSys: RootSys
    let strict: Bool
}

actor ParsedChordCache {
    private var cache: [ChordCacheKey: Chord?] = [:]

    private var hits: Int = 0
    private var misses: Int = 0
    
    func get(_ key: ChordCacheKey) -> CacheResult<Chord> {
        switch cache[key] {
        // kein Wert vorhanden
        case .none:
            misses += 1
//            print("\(cache.count) hits \(hits) misses \(misses) \(key.chord)")
            return .miss
            
        // Wert nil oder ParsedChord
        case .some(let value):
            hits += 1
//            print("\(cache.count) hits \(hits) misses \(misses) \(key.chord)")
            return .hit(value)
        }
    }

    func set(_ key: ChordCacheKey, value: Chord?) {
        cache[key] = value
    }
}

private struct ParserState {
    var chords: [TextElement] = []
    var texts: [TextElement] = []
    var plainText = ""

    var nextChordPosition: Double = 0
    var nextTextPosition: Double = 0
    var minNextChordPosition: Double = 0

    var numDirectives = 0
    var isFinished = false      // falls src ohne newline endet
    var currentSection: Int = 0
}

nonisolated
public class ChordProParser {
    private let directiveManager = DirectiveManager()
    private let userSettings: UserSettingsSendable
    private let songTranspose: Int
    private let forPrinting: Bool
    private let showChords: Bool
    private let textFollowsChords: Bool
    
    private let rootSys: RootSys
    private let txtf: UIFont
    private let chordf: UIFont
        
    private var parserState = ParserState()
    private static let sharedChordCache = ParsedChordCache()
    private var currentKey: Key?
    private let chordPadding: Double = 3
    private let transposeKey: Bool
    
    public init(userSettings: UserSettingsSendable, songTranspose: Int, forPrinting: Bool = false) {
        self.userSettings = userSettings
        self.songTranspose = songTranspose
        self.forPrinting = forPrinting
        self.rootSys = userSettings.isGermanNotation ? .german : .common
        self.txtf = forPrinting ? userSettings.txtPDFUIFont : userSettings.txtUIFont
        self.chordf = forPrinting ? userSettings.chordPDFUIFont : userSettings.chordUIFont
        
        self.showChords = !userSettings.hidechords
        self.textFollowsChords = userSettings.textfollowschords
        self.transposeKey = userSettings.transposeKey
        
//        print(KeySystem().toString())
    }
    
    func getDirectiveManager() -> DirectiveManagerSendable {
        return DirectiveManagerSendable(directiveManager: directiveManager)
    }
    
    @concurrent
    public func chunksAsStream(tokens: AsyncThrowingStream<Token, Error>) async -> ParserResult {

        let (stream, continuation) = AsyncThrowingStream<[SongRenderChunk], Error>.makeStream()

        let userSettings = userSettings
        let songTranspose = songTranspose
        let forPrinting = forPrinting

        let resultTask = Task {
            // print("chunksAsStream:", Thread.currentThread)
            
            let parser = ChordProParser(userSettings: userSettings, songTranspose: songTranspose, forPrinting: forPrinting)

            do {
                for try await token in tokens {
                    try Task.checkCancellation()

                    let chunk = try await parser.consume(token)
                    if !chunk.isEmpty {
                        continuation.yield(chunk)
                    }
                }

                let final = try await parser.consume(nil)
                if !final.isEmpty {
                    continuation.yield(final)
                }

                continuation.finish()
                return parser.getDirectiveManager()
                
            } catch is CancellationError {
                continuation.finish()
                return parser.getDirectiveManager()
            } catch {
                continuation.finish(throwing: error)
                throw error
            }
        }

        return ParserResult(
            stream: stream,
            directiveManager: resultTask
        )
    }
    
    private func consume(_ token: Token?) async throws -> [SongRenderChunk] {
        if token != nil { parserState.isFinished = false }
        
        switch token {
            
        case .bracketEnclosed(let chord):
            // Cache fragen
            let key = ChordCacheKey(chord: chord, rootSys: rootSys, strict: true)
            var p: Chord?
            
            switch await ChordProParser.sharedChordCache.get(key) {
            case .miss:
                let parsed = try Chord.parse(chord, preferedGermanParsing: rootSys == .german, strict: true)
                await ChordProParser.sharedChordCache.set(key, value: parsed)
                p = parsed

            case .hit(let value):
                p = value   // kann nil oder ParsedChord sein
            }
            
            if let pchord = p {
                let position = max(parserState.nextChordPosition, parserState.minNextChordPosition)
                let transposeParm = TransposeParm(semitones: songTranspose + directiveManager.transpose, fromKey: currentKey, transposeKey: transposeKey)

                let (str, tchord) = pchord.toString(rootSys: rootSys, transposeParm: transposeParm)
                let strLen = sizeOfString(string: str, font: chordf)
                parserState.chords.append(TextElement(txt: str, isChordcomment: false, fontOffset: position, background: true, chord: tchord ?? pchord))

                // wenn Chords angezeigt werden, soll sich der Text danach richten
                if showChords {
                    // textFollowsChords == true: Text genau an Chord-Position, wird danach aber evtl. auseinander gezogen
                    // sym !== symLine.symbols.first && txt.isEmpty: Text nur beim ersten Mal genau an Chord-Position, wird danach aber nicht mehr auseinander gezogen (z.B.: [Bb][B][Am]c[A]d[A]e[A][Bb][B][Am]c[A]d[A]e[A])
                    if textFollowsChords || (parserState.chords.count > 1 && parserState.texts.isEmpty) {
                        parserState.nextTextPosition = position
                    }
                }
                
                parserState.nextChordPosition = position + strLen
                parserState.minNextChordPosition = parserState.nextChordPosition + chordPadding
                
            } else {
                // kein Chord -> chordcomment oder section
                let position = parserState.nextChordPosition
                let isChordcomment = chord.starts(with: "*")
                let str = processReplace(srcline: isChordcomment ? String(chord.dropFirst()) : chord, rootSys: rootSys)
                let strLen = sizeOfString(string: str, font: chordf)
                parserState.chords.append(TextElement(txt: str, isChordcomment: isChordcomment, fontOffset: position, background: false, chord: nil))
                
                if showChords {
                    // siehe oben
                    if textFollowsChords || (parserState.chords.count > 1 && parserState.texts.isEmpty) {
                        parserState.nextTextPosition = position
                    }
                }
                
                parserState.nextChordPosition = position + strLen
                parserState.minNextChordPosition = parserState.nextChordPosition
            }

            return []
            
        case .curlyEnclosed(let directive):
            parserState.numDirectives += 1

            if let d = directiveManager.addDirective(processReplace(srcline: directive, rootSys: rootSys)) {

                switch d {
                case .column_break:
                    return [SongRenderChunk(content: .columnbreak)]

                case .new_page:
                    return [SongRenderChunk(content: .newpage)]

                case .start_of_verse, .start_of_bridge, .start_of_chorus:
                    parserState.currentSection += 1
                    let val = directiveManager.getDirective(d.rawValue) ?? ""
                    return [SongRenderChunk(content: .sectionStarted(val, parserState.currentSection - 1))]
                    
                case .end_of_verse, .end_of_bridge, .end_of_chorus:
                    return [SongRenderChunk(content: .sectionEnded)]
                    
                case .comment, .comment_box, .comment_italic:
                    let val = directiveManager.getDirective(d.rawValue) ?? ""
                    let strLen = sizeOfString(string: val, font: txtf)
                    parserState.texts.append(TextElement(txt: val, isChordcomment: false, fontOffset: parserState.nextTextPosition, background: false, chord: nil))
                    textCleanup(str: val, strLen: strLen)

                case .key:
                    // currentKey aktualisieren
                    if let key = directiveManager.getDirective(DirectiveType.key.rawValue) {
                        if let parsed = try Chord.parse(key, preferedGermanParsing: false, strict: true) {
                            currentKey = Key(note: parsed.note, mode: parsed.mode == .minor ? .minor : .major)
                        }
                    }

                default: break
                }
            } else {
                let str = processReplace(srcline: directive, rootSys: rootSys)
                let strLen = sizeOfString(string: str, font: txtf)
                parserState.texts.append(TextElement(txt: str, isChordcomment: false, fontOffset: parserState.nextTextPosition, background: false, chord: nil))
                textCleanup(str: str, strLen: strLen)
            }
            
            return []
            
        case .text(let text):
            let str = processReplace(srcline: text, rootSys: rootSys)
            let strLen = sizeOfString(string: str, font: txtf)
            parserState.texts.append(TextElement(txt: str, isChordcomment: false, fontOffset: parserState.nextTextPosition, background: false, chord: nil))
            parserState.plainText.append(str)
            
            textCleanup(str: str, strLen: strLen)
            return []

        case .comment(let text):
            let strLen = sizeOfString(string: text, font: txtf)
            parserState.texts.append(TextElement(txt: text, isChordcomment: false, fontOffset: parserState.nextTextPosition, background: false, chord: nil))
            parserState.plainText.append(text)
            
            textCleanup(str: text, strLen: strLen)
            return []

        case .commentHidden(_):
            return []
            
        case .newLine, nil:
            let chunks = finalizeLine()
            resetLinestate()
            return chunks
        }
                
        /* ----- Ende func ----- */

        
        /* ----- lokale Hilfsfunktionen ----- */
        
        func finalizeLine() -> [SongRenderChunk] {
            if parserState.isFinished { return [] }
            parserState.isFinished = true
            
            // Falls Chords da sind und Text nur aus whitespaces besteht, dann wurde der Text nur aus den Chordzwischenräumen erzeugt: [Am]  [Am]  [Am]
            if !parserState.chords.isEmpty && !parserState.texts.isEmpty && ParserHelper.allWhitespace(elements: parserState.texts) {
                // Und dann muss er weg
                parserState.texts = []
                parserState.plainText = ""
            }
            
            var res: [SongRenderChunk] = []
            
            if parserState.chords.count == 1 && ParserHelper.allWhitespace(elements: parserState.texts), let chord = parserState.chords.first, chord.chord == nil, !chord.isChordcomment {
                // Sectionstart
                parserState.currentSection += 1
                res.append(SongRenderChunk(content: .sectionStarted(chord.txt, parserState.currentSection - 1)))
            } else {
                // Zeilen nur aus Directiven bestehend werden ignoriert, ansonsten Leerzeile
                if parserState.chords.isEmpty && ParserHelper.allWhitespace(elements: parserState.texts) {
                    if parserState.numDirectives == 0 {
                        res.append(SongRenderChunk(content: .emptyline))
                    }
                } else {
                    if ParserHelper.allWhitespace(elements: parserState.texts) {
                        // kein Text -> .chordline
                        res.append(SongRenderChunk(content: .chordline(parserState.chords)))
                    } else if parserState.chords.isEmpty {
                        // keine chords -> .textline
                        res.append(SongRenderChunk(content: .textline(parserState.texts, plaintext: parserState.plainText)))
                    } else {
                        // beides -> .splittedline
                        res.append(SongRenderChunk(content: .splittedline(chords: parserState.chords, texts: parserState.texts, plaintext: parserState.plainText)))
                    }
                }
            }

            return res
        }
        
        func resetLinestate() {
            parserState.texts = []
            parserState.chords = []
            parserState.plainText = ""
            parserState.nextChordPosition = 0
            parserState.nextTextPosition = 0
            parserState.minNextChordPosition = 0
            parserState.numDirectives = 0
        }
        
        func textCleanup(str: String, strLen: Double) {
            // Chordabstand erzeugen, falls nur Whitespace
            if str.trimmingCharacters(in: .whitespaces).count == 0 {
                parserState.nextChordPosition += sizeOfString(string: str, font: chordf)
            }
            
            // Text direkt hintereinander setzen
            parserState.nextTextPosition += strLen
            parserState.nextChordPosition = max(parserState.nextTextPosition, parserState.nextChordPosition)
        }
    }
    
    // Ersetzt Variablen durch ihren Wert: %{ variable }
    private func processReplace(srcline: String, rootSys: RootSys) -> String {
        if srcline.isEmpty { return srcline }
        var res = ""
        
        do {
            let lexer = ChordProLexer(input: srcline)
            
            while let token = lexer.nextVariableToken() {
                switch(token) {
                case .curlyEnclosed(let enc):   // %{ variable }
                    let txt = enc.trimmingCharacters(in: .whitespaces).lowercased()
                    var repl: String? = ""
                    if let dirval = directiveManager.getDirective(txt) {
                        repl = dirval
                    } else {
                        // key_actual und key_from werden automatisch generiert, wenn transpose verwendet wurde
                        if let special = DirectiveNamesSpecial(rawValue: txt), let key = directiveManager.getDirective(DirectiveType.key.rawValue), directiveManager.getDirective(DirectiveType.transpose.rawValue) != nil {
                            switch special {
                            case DirectiveNamesSpecial.key_actual:
                                // transponierter Key
                                let keySys = KeySystem()
                                repl = key
                                if let currentKey {
                                    let note = transposeKey ? keySys.transpose(from: currentKey, note: currentKey.note, by: songTranspose + directiveManager.transpose) :
                                                            keySys.transpose(note: currentKey.note, by: songTranspose + directiveManager.transpose)
                                
                                    if let note {
                                        repl = "\(note.toString(rootSys: rootSys))\(currentKey.mode.toString())"
                                    }
                                }
                                
                            case DirectiveNamesSpecial.key_from:
                                // ursprünglicher Key
                                if let key = directiveManager.getDirective(DirectiveType.key.rawValue) {
                                    repl = key
                                }
                            }
                        } else {
                            // wenn nichts generiert wurde, dann bleibt's beim Key
                            if let key = directiveManager.getDirective(DirectiveType.key.rawValue) {
                                repl = key
                            }
                        }
                    }
                    res += repl ?? ""
                    
                case .text(let txt):
                    res += txt
                    
                default:
                    break
                }
            }
        }
        
        return res
    }
    
    let textMetricsCache = TextMetricsCache()
    private func sizeOfString(string: String, font: UIFont) -> Double {
        return textMetricsCache.width(of: string, font: font)
    }
}

nonisolated
final class TextMetricsCache {
    private var cache: [String: Double] = [:]

    func width(of string: String, font: UIFont) -> Double {
        let key = "\(font.fontName)-\(font.pointSize)-\(string)"
        if let w = cache[key] { return w }
        let w = string.size(withAttributes: [.font: font]).width
        cache[key] = w
        return w
    }
}
