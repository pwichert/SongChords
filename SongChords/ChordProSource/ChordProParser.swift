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

struct SplittedLine: Identifiable, Sendable {
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

struct TextElement: Identifiable, Equatable, Sendable {
    let id = UUID()
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
    private let tokens: [Token]
    private let userSettings: UserSettings
    private let forPrinting: Bool
    private let directiveManager = DirectiveManager()
    
    public init(userSettings: UserSettings, songTranspose: Int, tokens: [Token], forPrinting: Bool) {
        self.songTranspose = songTranspose
        self.tokens = tokens
        self.userSettings = userSettings
        self.forPrinting = forPrinting
    }
    
    // Hauptmethode, um den gesamten Song zu parsen
    // Wandelt die Token-Folge in Section : Line : Element um
    // Directiven sind nicht mehr enthalten
    
    public func parse() throws -> SongRepresentation {
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
        
        while position < tokens.count {
            if Task.isCancelled { print("cancelled"); break }
            
            let token = tokens[position]
            
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
                
            case .newLine: break
                
            }
            
            // neue Zeile oder Ende?
            if .newLine == token || position == tokens.endIndex - 1 {
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
            
            position += 1
        }
        
        createSplittedLines()
        
//        print(sections.map { $0.linesToString() }.joined())
//        print(sections.map { $0.splToString() }.joined())

        let directiveManagerSendable = DirectiveManagerSendable(directiveManager: directiveManager)
        let sectionsSendable = sections.map( { CPPSectionSendable(cppSection: $0) })
        let sr = SongRepresentation(sections: sectionsSendable, directiveManager: directiveManagerSendable)

        return sr
        
        // Codevereinfachung
        
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
                            let tElem = TextElement(txt: chordtxt, fontOffset: position, background: true, chord: tchord)
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
                            let tElem = TextElement(txt: comment, fontOffset: position, background: false, chord: nil)
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
                            let tElem = TextElement(txt: txt, fontOffset: nextTextPosition, background: false, chord: nil)
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
        
        var src: String = srcline

        // TODO: Maskiertes \%{ fehlt hier noch. Außerdem sollte die Schleife sicherer werden.
        
        while true {
            let dirRepl = findSubstringBetweenDelimiters(mainString: src, startDelimiter: "%{", endDelimiter: "}")
            
            if dirRepl == nil { break }
            let str = dirRepl!.substring.trimmingCharacters(in: .whitespaces).lowercased()
            let s1Index = dirRepl!.startIndex
            let eIndex = dirRepl!.endIndex
            let sIndex = src.index(s1Index, offsetBy: -2)
            
            var repl: String?
            if str.count < 10000 && str.count > 0 {
                if let dirval = directiveManager.getDirective(str) {
                    repl = dirval
                } else {
                    if let special = DirectiveNamesSpecial(rawValue: str) {
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
            }
                        
            src = src[src.startIndex..<sIndex].appending(repl ?? "").appending(src[src.index(after: eIndex)...])
        }
        
        return src
    }
    
    private func findSubstringBetweenDelimiters(mainString: String, startDelimiter: String, endDelimiter: String) -> (substring: String, startIndex: String.Index, endIndex: String.Index)? {
        guard let rangeStart = mainString.range(of: startDelimiter),
              let rangeEnd = mainString.range(of: endDelimiter, range: rangeStart.upperBound..<mainString.endIndex)
        else {
            return nil
        }

        let startIndex = rangeStart.upperBound
        let endIndex = rangeEnd.lowerBound

        let substring = mainString[startIndex..<endIndex]

        return (String(substring), startIndex, endIndex)
    }
}

