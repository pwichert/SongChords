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
    
    let chord: ParsedChord?     // falls dieser Text ein Chord ist, für diagrammerzeugung merken
    
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

nonisolated
public class ChordProParser {
    private let directiveManager = DirectiveManager()
    private let userSettings: UserSettingsSendable
    private let songTranspose: Int
    private let forPrinting: Bool
    private let showChords: Bool
    private let textFollowsChords: Bool
    
    private var rootSystem: ChordRoot
    private let txtf: UIFont
    private let chordf: UIFont
        
    private var chords: [TextElement] = []
    private var texts: [TextElement] = []
    private var plainText: String = ""
    private var numDirectives: Int = 0
    private var isFinished: Bool = false     // falls src ohne newline endet
    
    private var nextChordPosition: Double = 0
    private var nextTextPosition: Double = 0
    private var minNextChordPosition: Double = 0
    private var currentSection: Int = 0

    private let chordPadding: Double = 3
        
    public init(userSettings: UserSettingsSendable, songTranspose: Int, forPrinting: Bool = false) {
        self.userSettings = userSettings
        self.songTranspose = songTranspose
        self.forPrinting = forPrinting
        self.rootSystem = userSettings.isGermanNotation ? EnglishGermanRoot() : EnglishDutchRoot()
        self.txtf = forPrinting ? userSettings.txtPDFUIFont : userSettings.txtUIFont
        self.chordf = forPrinting ? userSettings.chordPDFUIFont : userSettings.chordUIFont
        
        self.showChords = !userSettings.hidechords
        self.textFollowsChords = userSettings.textfollowschords
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

                    let chunk = try parser.consume(token)
                    if !chunk.isEmpty {
                        continuation.yield(chunk)
                    }
                }

                let final = try parser.consume(nil)
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
    
    private func consume(_ token: Token?) throws -> [SongRenderChunk] {
        if token != nil { isFinished = false }
        
        switch token {
            
        case .bracketEnclosed(let chord):
            if let pchord = ParsedChord.parse(chord, rootSystem: &rootSystem, strict: true) {
                let position = max(nextChordPosition, minNextChordPosition)

                let (str, tchord) = pchord.toString(transpose: songTranspose + directiveManager.transpose, rootSystem: &rootSystem)
                let strLen = sizeOfString(string: str, font: chordf)
                chords.append(TextElement(txt: str, isChordcomment: false, fontOffset: position, background: true, chord: tchord ?? pchord))
                
                // wenn Chords angezeigt werden, soll sich der Text danach richten
                if showChords {
                    // textFollowsChords == true: Text genau an Chord-Position, wird danach aber evtl. auseinander gezogen
                    // sym !== symLine.symbols.first && txt.isEmpty: Text nur beim ersten Mal genau an Chord-Position, wird danach aber nicht mehr auseinander gezogen (z.B.: [Bb][B][Am]c[A]d[A]e[A][Bb][B][Am]c[A]d[A]e[A])
                    if textFollowsChords || (chords.count > 1 && texts.isEmpty) {
                        nextTextPosition = position
                    }
                }
                
                nextChordPosition = position + strLen
                minNextChordPosition = nextChordPosition + chordPadding
                
            } else {
                // kein Chord -> chordcomment oder section
                let position = nextChordPosition
                let isChordcomment = chord.starts(with: "*")
                let str = processReplace(srcline: isChordcomment ? String(chord.dropFirst()) : chord, root: &rootSystem)
                let strLen = sizeOfString(string: str, font: chordf)
                chords.append(TextElement(txt: str, isChordcomment: isChordcomment, fontOffset: position, background: false, chord: nil))
                
                if showChords {
                    // siehe oben
                    if textFollowsChords || (chords.count > 1 && texts.isEmpty) {
                        nextTextPosition = position
                    }
                }
                
                nextChordPosition = position + strLen
                minNextChordPosition = nextChordPosition
            }

            return []
            
        case .curlyEnclosed(let directive):
            numDirectives += 1

            if let d = directiveManager.addDirective(processReplace(srcline: directive, root: &rootSystem)) {

                switch d {
                case .column_break:
                    return [SongRenderChunk(content: .columnbreak)]

                case .new_page:
                    return [SongRenderChunk(content: .newpage)]

                case .start_of_verse, .start_of_bridge, .start_of_chorus:
                    currentSection += 1
                    let val = directiveManager.getDirective(d.rawValue) ?? ""
                    return [SongRenderChunk(content: .sectionStarted(val, currentSection - 1))]
                    
                case .end_of_verse, .end_of_bridge, .end_of_chorus:
                    return [SongRenderChunk(content: .sectionEnded)]
                    
                case .comment, .comment_box, .comment_italic:
                    let val = directiveManager.getDirective(d.rawValue) ?? ""
                    let strLen = sizeOfString(string: val, font: txtf)
                    texts.append(TextElement(txt: val, isChordcomment: false, fontOffset: nextTextPosition, background: false, chord: nil))
                    textCleanup(str: val, strLen: strLen)

                default: break
                }
            } else {
                let str = processReplace(srcline: directive, root: &rootSystem)
                let strLen = sizeOfString(string: str, font: txtf)
                texts.append(TextElement(txt: str, isChordcomment: false, fontOffset: nextTextPosition, background: false, chord: nil))
                textCleanup(str: str, strLen: strLen)
            }
            
            return []
            
        case .text(let text):
            let str = processReplace(srcline: text, root: &rootSystem)
            let strLen = sizeOfString(string: str, font: txtf)
            texts.append(TextElement(txt: str, isChordcomment: false, fontOffset: nextTextPosition, background: false, chord: nil))
            plainText.append(str)
            
            textCleanup(str: str, strLen: strLen)
            return []

        case .comment(let text):
            let strLen = sizeOfString(string: text, font: txtf)
            texts.append(TextElement(txt: text, isChordcomment: false, fontOffset: nextTextPosition, background: false, chord: nil))
            plainText.append(text)
            
            textCleanup(str: text, strLen: strLen)
            return []

        case .commentHidden(_):
            return []
            
        case .newLine, nil:
            if let res = flush() { return res } else { return [] }
        }
                
        /* ----- Ende func ----- */

        
        /* ----- lokale Hilfsfunktionen ----- */

        func flush() -> [SongRenderChunk]? {
            if isFinished { return nil }
            isFinished = true
            
            // Falls Chords da sind und Text nur aus whitespaces besteht, dann wurde der Text nur aus den Chordzwischenräumen erzeugt: [Am]  [Am]  [Am]
            if !chords.isEmpty && !texts.isEmpty && ParserHelper.allWhitespace(elements: texts) {
                // Und dann muss er weg
                texts = []
                plainText = ""
            }
            
            var res: [SongRenderChunk] = []
            
            if chords.count == 1 && ParserHelper.allWhitespace(elements: texts), let chord = chords.first, chord.chord == nil, !chord.isChordcomment {
                // Sectionstart
                currentSection += 1
                res.append(SongRenderChunk(content: .sectionStarted(chord.txt, currentSection - 1)))
            } else {
                // Zeilen nur aus Directiven bestehend werden ignoriert, ansonsten Leerzeile
                if chords.isEmpty && ParserHelper.allWhitespace(elements: texts) {
                    if numDirectives == 0 {
                        res.append(SongRenderChunk(content: .emptyline))
                    }
                } else {
                    if ParserHelper.allWhitespace(elements: texts) {
                        // kein Text -> .chordline
                        res.append(SongRenderChunk(content: .chordline(chords)))
                    } else if chords.isEmpty {
                        // keine chords -> .textline
                        res.append(SongRenderChunk(content: .textline(texts, plaintext: plainText)))
                    } else {
                        // beides -> .splittedline
                        res.append(SongRenderChunk(content: .splittedline(chords: chords, texts: texts, plaintext: plainText)))
                    }
                }
            }

            texts = []
            chords = []
            plainText = ""
            nextChordPosition = 0
            nextTextPosition = 0
            minNextChordPosition = 0
            numDirectives = 0

            return res
        }
        
        func textCleanup(str: String, strLen: Double) {
            // Chordabstand erzeugen, falls nur Whitespace
            if str.trimmingCharacters(in: .whitespaces).count == 0 {
                nextChordPosition += sizeOfString(string: str, font: chordf)
            }
            
            // Text direkt hintereinander setzen
            nextTextPosition += strLen
            nextChordPosition = max(nextTextPosition, nextChordPosition)
        }
    }
    
    // Ersetzt Variablen durch ihren Wert: %{ variable }
    private func processReplace(srcline: String, root: inout ChordRoot) -> String {
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
                        if let special = DirectiveNamesSpecial(rawValue: txt) {
                            switch special {
                            case DirectiveNamesSpecial.key_actual:
                                let key = directiveManager.getDirective(DirectiveType.key.rawValue)
                                if let key = key {
                                    let chord = ParsedChord.parse(key, rootSystem: &root, strict: true)
                                    if let chord = chord {
                                        (repl, _) = chord.toString(transpose: directiveManager.transpose, rootSystem: &root)
                                    }
                                }
                                break
                            case DirectiveNamesSpecial.key_from:
                                let key = directiveManager.getDirective(DirectiveType.key.rawValue)
                                if let key = key {
                                    repl = key
                                }
                                break
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
    
    private func sizeOfString(string: String, font: UIFont) -> Double {
        let fontAttributes = [NSAttributedString.Key.font: font]
        return string.size(withAttributes: fontAttributes).width
    }
}
