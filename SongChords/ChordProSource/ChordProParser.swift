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
    public let id: Int
    
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
        self.id = cppSection.id
    }
}

public class CPPSection: Identifiable {
    public let id: Int
    
    var name: String
    var lines: [Line] = []
    var splittedLines: [SplittedLine] = []
    var isNewPage: Bool = false
    var isColumnBreak: Bool = false
    var col: Int = 0
    
    init(id: Int, name: String) {
        self.name = name
        self.id = id
    }
    
    func linesToString() -> String {
        return lines.map( { $0.toString() + "\n" } ).joined()
    }
    
    func splToString() -> String {
        return splittedLines.map( { $0.toString() + "\n" } ).joined()
    }
}

public struct SplittedLine: Identifiable, Sendable {
    public let id: Int
    
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

struct TextElement: Identifiable, Equatable, Sendable {
    let id: Int
    let txt: String
    let fontOffset: Double
    let background: Bool
    
    let chord: ParsedChord?     // falls dieser Text ein Chord ist, für diagrammerzeugung merken
    
    func toString() -> String {
        return ("[\(Int(fontOffset))]\(txt)")
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
    private let idManager = IdManager()
    
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
                    cSection = CPPSection(id: idManager.getSectionID(), name: "")
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
                    
                    var spl = SplittedLine(id: idManager.getLineID())
                    
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
                            let tElem = TextElement(id: idManager.getTextElementID(), txt: chordtxt, fontOffset: position, background: true, chord: tchord)
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
                            let tElem = TextElement(id: idManager.getTextElementID(), txt: comment, fontOffset: position, background: false, chord: nil)
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
                            let tElem = TextElement(id: idManager.getTextElementID(), txt: txt, fontOffset: nextTextPosition, background: false, chord: nil)
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

#if false
/// Ein inkrementell darstellbares Render-Fragment (z. B. eine fertige Zeile)
public enum SongRenderChunk: Sendable, Identifiable {
    case sectionStarted(String)
    case line(SplittedLine)
    case sectionEnded
    case newPage
    case columnBreak

    public var id: UUID { UUID() }
}

// MARK: - Streaming Parser

public final class ChordProStreamingParser {

    private let songTranspose: Int
    private let userSettings: UserSettings
    private let forPrinting: Bool
    private let directiveManager = DirectiveManager()

    private var sections: [CPPSection] = []
    private var cSection: CPPSection?
    private var cLine: Line?

    private var nextlineIsColumnBreak = false
    private var nextlineIsNewPage = false

    private var numChords = 0
    private var numDirectives = 0

    private var rootSystem: ChordRoot

    private let txtf: UIFont
    private let chordf: UIFont

    private let showChords: Bool
    private let textFollowsChords: Bool
    
    private let idManager = IdManager()
    
    public init(
        userSettings: UserSettings,
        songTranspose: Int,
        forPrinting: Bool
    ) {
        self.songTranspose = songTranspose
        self.userSettings = userSettings
        self.forPrinting = forPrinting

        self.txtf = forPrinting ? userSettings.txtPDFUIFont : userSettings.txtUIFont
        self.chordf = forPrinting ? userSettings.chordPDFUIFont : userSettings.chordUIFont

        self.showChords = !userSettings.hidechords
        self.textFollowsChords = userSettings.textfollowschords

        self.rootSystem = userSettings.isGermanNotation
            ? EnglishGermanRoot()
            : EnglishDutchRoot()
    }

    /// Konsumiert genau EIN Token und liefert ggf. ein Render-Chunk zurück
    public func consume(_ token: Token) throws -> SongRenderChunk? {
        if Task.isCancelled { return nil }

//        print(token)
//        return .sectionStarted("txt")
        
        switch token {

        case .curlyEnclosed(let directive):
            numDirectives += 1

            if let d = directiveManager.addDirective(processReplace(srcline: directive)) {
                switch d {
                case .column_break: nextlineIsColumnBreak = true
                case .new_page: nextlineIsNewPage = true

                case .start_of_verse, .start_of_bridge, .start_of_chorus:
                    let val = directiveManager.getDirective(d.rawValue) ?? ""
                    cSection = nil
                    let section = getSection()
                    section.name = val
                    setSectionDirectives()
                    return .sectionStarted(val)

                case .end_of_verse, .end_of_bridge, .end_of_chorus:
                    cSection = nil
                    return .sectionEnded

                case .comment, .comment_box, .comment_italic:
                    let val = directiveManager.getDirective(d.rawValue) ?? ""
                    let strLen = sizeOfString(string: val, font: txtf)
                    getLine().elements.append(Element(type: .comment(val, strLen)))
                    setLineDirectives()

                default: break
                }
            } else {
                let str = processReplace(srcline: directive)
                let strLen = sizeOfString(string: str, font: txtf)
                getLine().elements.append(Element(type: .text(str, strLen)))
                setLineDirectives()
            }

        case .bracketEnclosed(let chord):
            numChords += 1

            if chord.starts(with: "*") {
                let str = processReplace(srcline: String(chord.dropFirst()))
                let strLen = sizeOfString(string: str, font: chordf)
                getLine().elements.append(Element(type: .chordcomment(str, strLen, true)))
            } else {
                if let pchord = ParsedChord.parse(chord, rootSystem: &rootSystem, strict: true) {
                    let (str, tchord) = pchord.toString(
                        transpose: songTranspose + directiveManager.transpose,
                        rootSystem: &rootSystem
                    )
                    let strLen = sizeOfString(string: str, font: chordf)
                    getLine().elements.append(Element(type: .chord(str, tchord ?? pchord, strLen)))
                } else {
                    let str = processReplace(srcline: chord)
                    let strLen = sizeOfString(string: str, font: chordf)
                    getLine().elements.append(Element(type: .chordcomment(str, strLen, false)))
                }
            }
            setLineDirectives()

        case .text(let text):
            let str = processReplace(srcline: text)
            let strLen = sizeOfString(string: str, font: txtf)
            getLine().elements.append(Element(type: .text(str, strLen)))
            setLineDirectives()

        case .comment(let text):
            let str = processReplace(srcline: text)
            let strLen = sizeOfString(string: str, font: txtf)
            getLine().elements.append(Element(type: .comment(str, strLen)))
            setLineDirectives()

        case .commentHidden(_):
            break

        case .newLine:
            break
        }

        // Zeilenabschluss?
        if token == .newLine {
            let chunk = finalizeLineIfNeeded()
            return chunk
        }

        return nil
    }

    /// MUSS am Ende einmal aufgerufen werden
    public func finish() -> [SongRenderChunk] {
        var chunks: [SongRenderChunk] = []
        if let last = finalizeLineIfNeeded() {
            chunks.append(last)
        }
        return chunks
    }

    // MARK: - Helpers (leicht gekürzt, Logik identisch)

    private func finalizeLineIfNeeded() -> SongRenderChunk? {
        guard let line = cLine else { return nil }

        defer {
            cLine = nil
            numDirectives = 0
            numChords = 0
        }

        let spl = buildSplittedLine(from: line)
        return .line(spl)
    }

    private func buildSplittedLine(from line: Line) -> SplittedLine {
        var spl = SplittedLine(id: idManager.getLineID(), chords: [], texts: [])
        var nextChordPosition: Double = 0
        var nextTextPosition: Double = 0
        var minNextChordPosition: Double = 0
        let chordPadding: Double = 3
        
        for elem in line.elements {
            switch elem.type {
            case .chord(let chordtxt, let tchord, let len):
                let position = max(nextChordPosition, minNextChordPosition)
                spl.chords.append(
                    TextElement(id: idManager.getTextElementID(), txt: chordtxt, fontOffset: position, background: true, chord: tchord)
                )
                if showChords, textFollowsChords || (spl.chords.count > 1 && spl.texts.isEmpty) {
                    nextTextPosition = position
                }
                nextChordPosition = position + len
                minNextChordPosition = nextChordPosition + chordPadding

            case .chordcomment(let comment, let len, _):
                let position = nextChordPosition
                spl.chords.append(
                    TextElement(id: idManager.getTextElementID(), txt: comment, fontOffset: position, background: false, chord: nil)
                )
                nextChordPosition = position + len
                minNextChordPosition = nextChordPosition

            case .text(let txt, let len), .comment(let txt, let len):
                spl.texts.append(
                    TextElement(id: idManager.getTextElementID(), txt: txt, fontOffset: nextTextPosition, background: false, chord: nil)
                )
                spl.plainText.append(txt)
                nextTextPosition += len
                nextChordPosition = max(nextTextPosition, nextChordPosition)
            }
        }

        return spl
    }

    private func setLineDirectives() {
        if nextlineIsNewPage { getLine().lineIsNewPage = true }
        if nextlineIsColumnBreak { getLine().lineIsColumnBreak = true }
        nextlineIsColumnBreak = false
        nextlineIsNewPage = false
    }

    private func setSectionDirectives() {
        if nextlineIsNewPage { getSection().isNewPage = true }
        if nextlineIsColumnBreak { getSection().isColumnBreak = true }
        nextlineIsColumnBreak = false
        nextlineIsNewPage = false
    }

    private func getSection() -> CPPSection {
        if cSection == nil {
            cSection = CPPSection(id: idManager.getSectionID(), name: "")
            sections.append(cSection!)
            cLine = nil
        }
        return cSection!
    }

    private func getLine() -> Line {
        let section = getSection()
        if cLine == nil {
            cLine = Line()
            section.lines.append(cLine!)
        }
        return cLine!
    }

    private func processReplace(srcline: String) -> String {
        var root = rootSystem
        return srcline // vereinfachte Weiterverwendung der existierenden Logik
    }

    private func sizeOfString(string: String, font: UIFont) -> Double {
        let fontAttributes = [NSAttributedString.Key.font: font]
        return string.size(withAttributes: fontAttributes).width
    }
}
#endif
