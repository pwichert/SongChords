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

// Sendable ist eig überflüssig, da per default MainActor isoliert
public final class SongRepresentation: Identifiable, Sendable {
    public let id = UUID()
    
    let sections: [CPPSectionSendable]
    let directiveManager: DirectiveManagerSendable
    
    init(sections: [CPPSectionSendable], directiveManager: DirectiveManagerSendable) {
        self.sections = sections
        self.directiveManager = directiveManager
    }
    
    public func toChordProString() -> String {
        var result = ""
        
        for section in sections {
            result += "'" + section.name + "'" + "\n"
            for line in section.lines {
                for element in line.elements {
                    switch element.type {
                    case .chord(let chord, _, _):
                        result += "[" + chord + "]"
                    case.chordcomment(let comment, _, _):
                        result += comment
                    case .text(let text, _):
                        result += text
                    case .comment(let text, _):
                        result += text
                    }
                }
                
                result += "\n"
            }
        }
        
        return result
    }
}

final class CPPSectionSendable: Identifiable, Sendable {
    public let id = UUID()
    
    let name: String
    let lines: [LineSendable]
    let splittedLines: [SplittedLine]
    let isNewPage: Bool
    let isColumnBreak: Bool
    let col: Int
    
    init(cppSection: CPPSection) {
        self.name = cppSection.name
        self.splittedLines = cppSection.splittedLines
        self.isNewPage = cppSection.isNewPage
        self.isColumnBreak = cppSection.isColumnBreak
        self.col = cppSection.col
        self.lines = cppSection.lines.map({ LineSendable(line: $0) })
    }
}

public class CPPSection: Identifiable {
    public let id = UUID()
    
    var name: String
    var lines: [Line] = []
    var splittedLines: [SplittedLine] = []
    var isNewPage: Bool = false
    var isColumnBreak: Bool = false
    var col: Int = 0
    
    init(name: String) {
        self.name = name
    }
    
    func linesToString() -> String {
        return lines.map( { $0.toString() + "\n" } ).joined()
    }
    
    func splToString() -> String {
        return splittedLines.map( { $0.toString() + "\n" } ).joined()
    }
}

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

struct LineSendable: Identifiable, Sendable {
    let id = UUID()
    let elements: [Element]
    let lineIsColumnBreak: Bool
    let lineIsNewPage: Bool
    
    init(line: Line) {
        self.elements = line.elements
        self.lineIsColumnBreak = line.lineIsColumnBreak
        self.lineIsNewPage = line.lineIsNewPage
    }
    
    func toString() -> String {
        let res = elements.map( { $0.toString() + " " } ).joined()
        return "[np:\(lineIsNewPage)][cb:\(lineIsColumnBreak)]\(res)"
    }
}

class Line: Identifiable {
    let id = UUID()
    var elements: [Element] = []
    var lineIsColumnBreak: Bool = false
    var lineIsNewPage: Bool = false
    
    func toString() -> String {
        let res = elements.map( { $0.toString() + " " } ).joined()
        return "[np:\(lineIsNewPage)][cb:\(lineIsColumnBreak)]\(res)"
    }
}

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

struct Element: Identifiable, Sendable {
    let id = UUID()
    let type: ElementType
    
    func toString() -> String {
        var res: String = ""
        
        switch type {
        case .chord(let string, _, _):
            res = "[\(string)]"
        case .chordcomment(let string, _, _):
            res = "[*\(string)]"
        case .comment(let string, _):
            res = "#:\(string)"
        case .text(let string, _):
            res = "\(string)"
        }
        
        return res
    }
}

enum ElementType: Sendable {
    case chord(String, ParsedChord, Double)
    case chordcomment(String, Double, Bool)
    case comment(String, Double)
    case text(String, Double)
}

public class ChordProParser {
    private let songTranspose: Int
    private let tokens: AsyncThrowingStream<Token, any Error>
    private let userSettings: UserSettings
    private let forPrinting: Bool
    private let directiveManager = DirectiveManager()
    
    public init(userSettings: UserSettings, songTranspose: Int, tokens: AsyncThrowingStream<Token, any Error>, forPrinting: Bool) {
        self.songTranspose = songTranspose
        self.tokens = tokens
        self.userSettings = userSettings
        self.forPrinting = forPrinting
    }
    
    // Hauptmethode, um den gesamten Song zu parsen
    // Wandelt die Token-Folge in Section : Line : Element um
    // Directiven sind nicht mehr enthalten
    
    public func parse() async throws -> SongRepresentation {
        var sections: [CPPSection] = []
        
        var cSection: CPPSection?
        var cLine: Line?
        
        var nextlineIsColumnBreak: Bool = false
        var nextlineIsNewPage: Bool = false
        
        var position: Int = 0
        var numChords: Int = 0
        var numDirectives: Int = 0
        
        let txtf = forPrinting ? userSettings.txtPDFUIFont : userSettings.txtUIFont
        let chordf = forPrinting ? userSettings.chordPDFUIFont : userSettings.chordUIFont
        
        let showChords: Bool = !userSettings.hidechords
        let textFollowsChords: Bool = userSettings.textfollowschords
        
        var rootSystem: ChordRoot = userSettings.isGermanNotation ? EnglishGermanRoot() : EnglishDutchRoot()
        
        for try await token in tokens {
            if Task.isCancelled { print("cancelled"); break }
            
            //            let token = tokens[position]
            
            switch token {
            case .curlyEnclosed(let directive):
                // Directiven selbst werden nicht mehr gespeichert, sondern nur noch ausgeführt.
                // D.h. sie erzeugen Texte, Comments oder section-Struktur
                numDirectives += 1
                
                if let d = directiveManager.addDirective(processReplace(srcline: directive, root: &rootSystem)) {
                    switch d {
                        // Markiert für die nächste Zeile ColumnBreak oder NewPage
                    case .column_break: nextlineIsColumnBreak = true
                    case .new_page: nextlineIsNewPage = true
                        
                    case .start_of_verse, .start_of_bridge, .start_of_chorus:
                        let val = directiveManager.getDirective(d.rawValue) ?? ""
                        cSection = nil
                        getSection().name = val
                        setSectionDirectives()
                        
                    case .end_of_verse, .end_of_bridge, .end_of_chorus:
                        cSection = nil
                        
                    case .comment, .comment_box, .comment_italic:
                        let val = directiveManager.getDirective(d.rawValue) ?? ""
                        let strLen = sizeOfString(string: val, font: txtf)
                        getLine().elements.append(Element(type: .comment(val, strLen)))
                        setLineDirectives()
                        
                    default: break
                    }
                } else {
                    let str = processReplace(srcline: directive, root: &rootSystem)
                    let strLen = sizeOfString(string: str, font: txtf)
                    getLine().elements.append(Element(type: .text(str, strLen)))
                    setLineDirectives()
                }
                
            case .bracketEnclosed(let chord):
                numChords += 1
                if chord.starts(with: "*") {
                    let str = processReplace(srcline: String(chord.dropFirst()), root: &rootSystem)
                    let strLen = sizeOfString(string: str, font: chordf)
                    getLine().elements.append(Element(type: .chordcomment(str, strLen, true)))  // "*" merken
                } else {
                    if let pchord = ParsedChord.parse(chord, rootSystem: &rootSystem, strict: true) {
                        let (str, tchord) = pchord.toString(transpose: songTranspose + directiveManager.transpose, rootSystem: &rootSystem)
                        let strLen = sizeOfString(string: str, font: chordf)
                        getLine().elements.append(Element(type: .chord(str, tchord ?? pchord, strLen)))
                    } else {
                        let str = processReplace(srcline: chord, root: &rootSystem)
                        let strLen = sizeOfString(string: str, font: chordf)
                        getLine().elements.append(Element(type: .chordcomment(str, strLen, false)))
                    }
                }
                setLineDirectives()
                
            case .text(let text):
                let str = processReplace(srcline: text, root: &rootSystem)
                let strLen = sizeOfString(string: str, font: txtf)
                getLine().elements.append(Element(type: .text(str, strLen)))
                setLineDirectives()
                
            case .comment(let text):
                let str = processReplace(srcline: text, root: &rootSystem)
                let strLen = sizeOfString(string: str, font: txtf)
                getLine().elements.append(Element(type: .comment(str, strLen)))
                setLineDirectives()
                
            case .commentHidden(_): break
                
            case .newLine:
                finishLine()
            }
            
            position += 1
        }
        
        finishLine()
        
        createSplittedLines()
        
        //        print(sections.map { $0.linesToString() }.joined())
        //        print(sections.map { $0.splToString() }.joined())
        
        let directiveManagerSendable = DirectiveManagerSendable(directiveManager: directiveManager)
        let sectionsSendable = sections.map( { CPPSectionSendable(cppSection: $0) })
        let sr = SongRepresentation(sections: sectionsSendable, directiveManager: directiveManagerSendable)
        
        return sr
        
        // Codevereinfachung
        
        func finishLine() {
            // Zeileninhalt in den aktuellen Abschnitt einfügen.
            if numChords == 1 && onlyWhitespaceOrChordCommentForSection(elements: cLine?.elements ?? []) {
                // Section-Name [abc], einzelner ChordComment (ohne "*") in Zeile entdeckt:
                
                // neuen Sectionnamen festlegen
                var newSectionName = ""
                if let cSection = cSection, let cLine = cLine {
                    if let elem = getFirstChordComment(elements: cLine.elements),
                       case let .chordcomment(comment, _, _) = elem.type {
                        newSectionName = comment
                    }
                    
                    // alte Section abschließen, aber aktuelle Zeile löschen, da sie nur aus [Section] besteht
                    // vor dem Löschen die Info übernehmen
                    nextlineIsNewPage = cLine.lineIsNewPage
                    nextlineIsColumnBreak = cLine.lineIsColumnBreak
                    cSection.lines = cSection.lines.dropLast()
                }
                
                // neue Section erzeugen
                cSection = nil
                setSectionDirectives()
                getSection().name = newSectionName
            } else if numDirectives > 0 && cLine != nil && onlyWhitespace(elements: cLine?.elements ?? []) {
                // Zeile löschen, falls sie nur aus Directiven (+ evtl. WhiteSpace) besteht
                if let cSection = cSection {
                    cSection.lines = cSection.lines.dropLast()
                }
            } else if numDirectives == 0 && cLine == nil {
                // leere Zeile, bleibt erhalten
                _ = getLine(true)
            }
            
            // neue Zeile starten
            cLine = nil
            numDirectives = 0
            numChords = 0
        }
        
        func setLineDirectives() {
            if nextlineIsNewPage { getLine().lineIsNewPage = nextlineIsNewPage }
            if nextlineIsColumnBreak { getLine().lineIsColumnBreak = nextlineIsColumnBreak }
            nextlineIsColumnBreak = false
            nextlineIsNewPage = false
        }
        
        func setSectionDirectives() {
            if nextlineIsNewPage { getSection().isNewPage = nextlineIsNewPage }
            if nextlineIsColumnBreak { getSection().isColumnBreak = nextlineIsColumnBreak }
            nextlineIsNewPage = false
            nextlineIsColumnBreak = false
        }
        
        func getSection(_ new: Bool = false) -> CPPSection {
            if cSection == nil || new {
                // leere sections vermeiden
                if let last = sections.last, last.lines.isEmpty && last.name.isEmpty{
                    cSection = last
                } else {
                    cSection = CPPSection(name: "")
                    sections.append(cSection!)
                }
                cLine = nil
            }
            return cSection!
        }
        
        func getLine(_ new: Bool = false) -> Line {
            let section = getSection()
            if cLine == nil || new {
                cLine = Line()
                section.lines.append(cLine!)
            }
            return cLine!
        }
        
        // Teil 2, erzeugen der Chord-/Textzeilen
        func createSplittedLines() {
            
            let chordPadding: Double = 3
            var currentColumn: Int = 0
            
            for section in sections {
                if section.isColumnBreak {
                    if directiveManager.columns > 1 { currentColumn = (currentColumn + 1) % directiveManager.columns } else { currentColumn += 1 }
                }
                section.col = currentColumn
                
                for line in section.lines {
                    if Task.isCancelled { print("cancelled"); return }
                    
                    var nextChordPosition: Double = 0
                    var nextTextPosition: Double = 0
                    var minNextChordPosition: Double = 0
                    
                    var spl = SplittedLine()
                    
                    if line.lineIsNewPage { spl.onNewPage = true }
                    
                    // column_break. Falls kein col gesetzt wurde, einfach hochzählen
                    if line.lineIsColumnBreak {
                        if directiveManager.columns > 1 { currentColumn = (currentColumn + 1) % directiveManager.columns } else { currentColumn += 1 }
                    }
                    
                    spl.col = currentColumn
                    
                    for elem in line.elements {
                        switch elem.type {
                        case .chord(let chordtxt, let tchord, let len):
                            let position = max(nextChordPosition, minNextChordPosition)
                            let tElem = TextElement(txt: chordtxt, isChordcomment: false, fontOffset: position, background: true, chord: tchord)
                            spl.chords.append(tElem)
                            
                            // wenn Chords angezeigt werden, soll sich der Text danach richten
                            if showChords {
                                // textFollowsChords == true: Text genau an Chord-Position, wird danach aber evtl. auseinander gezogen
                                // sym !== symLine.symbols.first && txt.isEmpty: Text nur beim ersten Mal genau an Chord-Position, wird danach aber nicht mehr auseinander gezogen (z.B.: [Bb][B][Am]c[A]d[A]e[A][Bb][B][Am]c[A]d[A]e[A])
                                if textFollowsChords || (spl.chords.count > 1 && spl.texts.isEmpty) {
                                    nextTextPosition = position
                                }
                            }
                            
                            nextChordPosition = position + len
                            minNextChordPosition = nextChordPosition + chordPadding
                            
                        case .chordcomment(let comment, let len, _):
                            let position = nextChordPosition
                            let tElem = TextElement(txt: comment, isChordcomment: false, fontOffset: position, background: false, chord: nil)
                            spl.chords.append(tElem)
                            
                            if showChords {
                                // siehe oben
                                if textFollowsChords || (spl.chords.count > 1 && spl.texts.isEmpty) {
                                    nextTextPosition = position
                                }
                            }
                            
                            nextChordPosition = position + len
                            minNextChordPosition = nextChordPosition
                            
                        case .text(let txt, let len), .comment(let txt, let len):
                            let tElem = TextElement(txt: txt, isChordcomment: false, fontOffset: nextTextPosition, background: false, chord: nil)
                            spl.texts.append(tElem)
                            spl.plainText.append(txt)
                            
                            // Chordabstand erzeugen, falls Whitespace
                            if txt.trimmingCharacters(in: .whitespaces).count == 0 {
                                nextChordPosition += sizeOfString(string: txt, font: chordf)
                            }
                            
                            // Text direkt hintereinander setzen
                            nextTextPosition += len
                            
                            nextChordPosition = max(nextTextPosition, nextChordPosition)
                        }
                    }
                    
                    // Falls Chords da sind und Text nur aus whitespaces besteht, dann wurde der Text nur aus den Chordzwischenräumen erzeugt: [Am]  [Am]  [Am]
                    if !spl.chords.isEmpty && !spl.texts.isEmpty {
                        var isWhitespace = true
                        for t in spl.texts {
                            if t.txt.trimmingCharacters(in: .whitespaces).count > 0 {
                                isWhitespace = false
                            }
                        }
                        
                        // Und dann muss er weg
                        if isWhitespace {
                            spl.texts = []
                            spl.plainText = ""
                        }
                    }
                    
                    section.splittedLines.append(spl)
                }
            }
        }
    }
    
    private func sizeOfStringPart(str: String, end: Int, font: UIFont) -> Double {
        let iStart = str.startIndex
        let i2 = str.index(iStart, offsetBy: end)
        
        let x = String(str[iStart..<i2])
        //        print("."+String(x)+".")
        return sizeOfString(string: x, font: font)
    }
    
    private func sizeOfString(string: String, font: UIFont) -> Double {
        let fontAttributes = [NSAttributedString.Key.font: font]
        return string.size(withAttributes: fontAttributes).width
    }
    
    private func onlyWhitespace(elements: [Element]) -> Bool {
        return elements.allSatisfy { element in
            if case .text(let text, _) = element.type, text.trimmingCharacters(in: .whitespaces).isEmpty { return true }
            return false
        }
    }
    
    private func onlyWhitespaceOrChordCommentForSection(elements: [Element]) -> Bool {
        return elements.allSatisfy { element in
            if case .text(let text, _) = element.type, text.trimmingCharacters(in: .whitespaces).isEmpty { return true }
            if case .chordcomment(_, _, let hasStar) = element.type, hasStar == false { return true }    // ohne "*"
            return false
        }
    }
    
    private func getFirstChordComment(elements: [Element]) -> Element? {
        for element in elements {
            if case .chordcomment = element.type {
                return element
            }
        }
        
        return nil
    }
    
    // Ersetzt Variablen durch ihren Wert: %{ variable }
    private func processReplace(srcline: String, root: inout ChordRoot) -> String {
        if srcline.isEmpty { return srcline }
        var res = ""
        
        do {
            let lexer = ChordProLexer(input: srcline)
            
            while let token = lexer.nextVariableToken() {
                switch(token) {
                case .curlyEnclosed(let enc):
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
}

/// Ein inkrementell darstellbares Render-Fragment (z. B. eine fertige Zeile)
public struct SongRenderChunk: Sendable, Identifiable {
    public let id: Int
    let content: chunkContent
    
    init(id: Int, content: chunkContent) {
        self.id = id
        self.content = content
    }
    
    public enum chunkContent {
        case sectionStarted(String)
        case sectionEnded
        case chordline([TextElement])
        case textline([TextElement], plaintext: String)
        case splittedline(chords: [TextElement], texts: [TextElement], plaintext: String)
        case chordplainline([TextElement])
        case textplainline(String)
        case comment([TextElement])
        case emptyline
        case newpage
        case columnbreak
    }
}

public class ViewFilter {
    let userSettings: UserSettings
    let showHeader: Bool
    let showText: Bool
    
    init(userSettings: UserSettings, showHeader: Bool, showText: Bool) {
        self.userSettings = userSettings
        self.showHeader = showHeader
        self.showText = showText
    }
    
    func chunksAsStream(chunks: AsyncThrowingStream<[SongRenderChunk], Error>) -> AsyncThrowingStream<[SongRenderChunk], Error> {
        AsyncThrowingStream { continuation in
            continuation.onTermination = { termination in
                //                print("chunk stream terminated:", termination)
            }
            
            Task {
                var chunkId: Int = 0

                func getId() -> Int {
                    chunkId += 1
                    return chunkId
                }
                
                do {
                    let hideChords = userSettings.hidechords
                    
                    for try await chunk in chunks {
                        try Task.checkCancellation()
                            
                        var res: [SongRenderChunk] = []
                        for c in chunk {
                            switch c.content {
                                
                            case .sectionStarted(let section):
                                if showHeader && section.trimmingCharacters(in: .whitespaces).count > 0 {
                                    res.append(SongRenderChunk(id: getId(), content: .sectionStarted(section)))
                                }
                                
                            case .chordline(let chords):
                                if !hideChords {
                                    if showText {
                                        res.append(SongRenderChunk(id: getId(), content: .chordline(chords)))
                                    } else {
                                        res.append(SongRenderChunk(id: getId(), content: .chordplainline(chords)))
                                    }
                                }

                            case .textline(let texts, let plaintext):
                                if showText {
                                    if !hideChords {
                                        res.append(SongRenderChunk(id: getId(), content: .textline(texts, plaintext: plaintext)))
                                    } else {
                                        res.append(SongRenderChunk(id: getId(), content: .textplainline(plaintext)))
                                    }
                                }
                                
                            case .splittedline(chords: let chords, texts: _, let plaintext):
                                // chords und texts sind gefüllt
                                if hideChords {
                                    if showText { res.append(SongRenderChunk(id: getId(), content: .textplainline(plaintext))) }
                                } else {
                                    if showText {
                                        res.append(SongRenderChunk(id: getId(), content: c.content))
                                    } else {
                                        res.append(SongRenderChunk(id: getId(), content: .chordplainline(chords)))
                                    }
                                }

                            case .newpage, .sectionEnded, .columnbreak:
                                // keine View zur Darstellung benötigt, wird nicht weitergereicht
                                break
                                
                            default:
                                res.append(SongRenderChunk(id: getId(), content: c.content))
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

internal class ParserHelper {
    static func allWhitespace(elements: [TextElement]) -> Bool {
        return elements.allSatisfy { $0.txt.trimmingCharacters(in: .whitespaces).isEmpty }
    }
}

public class ChordProParserII {
    private var chunkId: Int = 0
    
    private let directiveManager: DirectiveManager
    private let userSettings: UserSettings
    private let songTranspose: Int
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

    private let chordPadding: Double = 3
    
    init(directiveManager: DirectiveManager, userSettings: UserSettings, songTranspose: Int, forPrinting: Bool = false) {
        self.directiveManager = directiveManager
        self.userSettings = userSettings
        self.songTranspose = songTranspose
        self.rootSystem = userSettings.isGermanNotation ? EnglishGermanRoot() : EnglishDutchRoot()
        self.txtf = forPrinting ? userSettings.txtPDFUIFont : userSettings.txtUIFont
        self.chordf = forPrinting ? userSettings.chordPDFUIFont : userSettings.chordUIFont
        
        self.showChords = !userSettings.hidechords
        self.textFollowsChords = userSettings.textfollowschords
    }
    
    func chunksAsStream(tokens: AsyncThrowingStream<Token, Error>) -> AsyncThrowingStream<[SongRenderChunk], Error> {

        AsyncThrowingStream { continuation in
            continuation.onTermination = { termination in
//                print("chunk stream terminated:", termination)
            }

            Task {
//                var buffer: [SongRenderChunk] = []

                do {
                    for try await token in tokens {
                        try Task.checkCancellation()

                        let chunk = try consume(token)
                        if chunk.isEmpty { continue }
//                        buffer.append(contentsOf: chunk)
                        
                        // 🔥 Batch-Größe (tunen!)
//                        if buffer.count >= 100 {
                            continuation.yield(chunk)
//                            buffer.removeAll()
//                        }
                    }

                    // Ende flushen
                    let chunk = try consume(nil)
                    if !chunk.isEmpty {
                        // buffer.append(contentsOf: chunk)
                        continuation.yield(chunk)
                    }
                    
                    // if !buffer.isEmpty {
                    //     continuation.yield(buffer)
                    // }

                    continuation.finish()

                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
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
                    return [SongRenderChunk(id: getId(), content: .columnbreak)]

                case .new_page:
                    return [SongRenderChunk(id: getId(), content: .newpage)]

                case .start_of_verse, .start_of_bridge, .start_of_chorus:
                    let val = directiveManager.getDirective(d.rawValue) ?? ""
                    return [SongRenderChunk(id: getId(), content: .sectionStarted(val))]
                    
                case .end_of_verse, .end_of_bridge, .end_of_chorus:
                    return [SongRenderChunk(id: getId(), content: .sectionEnded)]
                    
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
            
        case .text(let text), .comment(let text):
            let str = processReplace(srcline: text, root: &rootSystem)
            let strLen = sizeOfString(string: str, font: txtf)
            texts.append(TextElement(txt: str, isChordcomment: false, fontOffset: nextTextPosition, background: false, chord: nil))
            plainText.append(str)
            
            textCleanup(str: str, strLen: strLen)
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
                res.append(SongRenderChunk(id: getId(), content: .sectionStarted(chord.txt)))
            } else {
                // Zeilen nur aus Directiven bestehend werden ignoriert, ansonsten Leerzeile
                if chords.isEmpty && ParserHelper.allWhitespace(elements: texts) {
                    if numDirectives == 0 {
                        res.append(SongRenderChunk(id: getId(), content: .emptyline))
                    }
                } else {
                    if ParserHelper.allWhitespace(elements: texts) {
                        // kein Text -> .chordline
                        res.append(SongRenderChunk(id: getId(), content: .chordline(chords)))
                    } else if chords.isEmpty {
                        // keine chords -> .textline
                        res.append(SongRenderChunk(id: getId(), content: .textline(texts, plaintext: plainText)))
                    } else {
                        // beides -> .splittedline
                        res.append(SongRenderChunk(id: getId(), content: .splittedline(chords: chords, texts: texts, plaintext: plainText)))
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
    
    private func getId() -> Int {
        chunkId += 1
        return chunkId
    }
}
