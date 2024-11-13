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

enum ParserError: Error {
//    case inputTooLarge
}

public class SongRepresentation: Identifiable {
    public let id = UUID()
    
    let sections: [Section]
    
    init(sections: [Section]) {
        self.sections = sections
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

class Section: Identifiable {
    let id = UUID()
    
    let name: String
    let lines: [Line]
    var splittedLines: [SplittedLine] = []
    
    init(name: String, lines: [Line]) {
        self.name = name
        self.lines = lines
    }
}

struct SplittedLine: Identifiable {
    public let id = UUID()
    
    var chords: [TextElement] = []
    var texts: [TextElement] = []
}

struct Line: Identifiable {
    let id = UUID()
    
    let elements: [Element]
    let lineIsColumnBreak: Bool
    let lineIsNewPage: Bool
}

struct TextElement: Identifiable {
    let id = UUID()
    
    let txt: String
    let fontOffset: Double
    let background: Bool
}

struct Element: Identifiable {
    let id = UUID()
    
    let type: ElementType
}

enum ElementType {    
    case chord(String, ParsedChord, Double)
    case chordcomment(String, Double, Bool)
    case comment(String, Double)
    case text(String, Double)
}

public struct ChordProParser {
    private let tokens: [Token]
    private let song: Song
    private let viewModel: ViewModel
    private let directiveManager = DirectiveManager()
    
    public init(viewModel: ViewModel, song: Song, tokens: [Token]) {
        self.song = song
        self.tokens = tokens
        self.viewModel = viewModel
    }
    
    // Hauptmethode, um den gesamten Song zu parsen
    // Wandelt die Token-Folge in Section : Line : Element um
    // Directiven sind nicht mehr enthalten
    
    public func parse() throws -> SongRepresentation {
        var sections: [Section] = []
        
        var currentLineElements: [Element] = []
        var currentSectionLines: [Line] = []
        var currentSectionName = ""
        
        var position: Int = 0
        var numChords: Int = 0
        var numDirectives: Int = 0
        
        var lineIsColumnBreak: Bool = false
        var lineIsNewPage: Bool = false
        
        var firstTime = true
        
        let txtf = viewModel.txtUIFont
        let chordf = viewModel.chordUIFont
        
        // feste Optionen
        let showText: Bool = true
        let textFollowsChords = false

        while position < tokens.count {
            if Task.isCancelled { print("cancelled"); break }

            let token = tokens[position]
            
            switch token {
            case .curlyEnclosed(let directive):
                numDirectives += 1
                
                if let d = directiveManager.addDirective(processReplace(viewModel: viewModel, song: song, srcline: directive)) {
                    switch d {
                    case .column_break: lineIsColumnBreak = true
                    case .new_page:     lineIsNewPage = true
                        
                    case .start_of_verse, .start_of_bridge, .start_of_chorus:
                        let val = directiveManager.getDirective(d.rawValue) ?? ""
                        // aktuelle Elemente noch in alte Section übernehmen
                        appendCurrentLineElements()
                        appendLastSection()
                        currentSectionName = val
                        
                    case .end_of_verse, .end_of_bridge, .end_of_chorus:
                        // aktuelle Elemente noch in alte Section übernehmen
                        appendCurrentLineElements()
                        appendLastSection()
                        currentSectionName = ""
                        
                    case .comment, .comment_box, .comment_italic:
                        let val = directiveManager.getDirective(d.rawValue) ?? ""
                        let strLen = sizeOfString(string: val, font: txtf)
                        currentLineElements.append(Element(type: .comment(val, strLen)))
                        
                    default: break
                    }
                } else {
                    let str = processReplace(viewModel: viewModel, song: song, srcline: directive)
                    let strLen = sizeOfString(string: str, font: txtf)
                    currentLineElements.append(Element(type: .text(str, strLen)))
                }
                
            case .bracketEnclosed(let chord):
                numChords += 1
                if chord.starts(with: "*") {
                    let str = processReplace(viewModel: viewModel, song: song, srcline: String(chord.dropFirst()))
                    let strLen = sizeOfString(string: str, font: chordf)
                    currentLineElements.append(Element(type: .chordcomment(str, strLen, true)))  // "*" merken
                } else {
                    if let pchord = parseChord(chord, convertGerman: viewModel.isGermanNotation) {
                        let str = pchord.toString(transpose: song.transpose + directiveManager.transpose, convertGerman: viewModel.isGermanNotation)
                        let strLen = sizeOfString(string: str, font: chordf)
                        currentLineElements.append(Element(type: .chord(str, pchord, strLen)))
                    } else {
                        let str = processReplace(viewModel: viewModel, song: song, srcline: chord)
                        let strLen = sizeOfString(string: str, font: chordf)
                        currentLineElements.append(Element(type: .chordcomment(str, strLen, false)))
                    }
                }
                
            case .text(let text):
                let str = processReplace(viewModel: viewModel, song: song, srcline: text)
                let strLen = sizeOfString(string: str, font: txtf)
                currentLineElements.append(Element(type: .text(str, strLen)))
                
            case .comment(let text):
                let str = processReplace(viewModel: viewModel, song: song, srcline: text)
                let strLen = sizeOfString(string: str, font: txtf)
                currentLineElements.append(Element(type: .comment(str, strLen)))
                
            case .newLine: break
                
            }
            
            // neue Zeile oder Ende?
            if .newLine == token || position == tokens.endIndex - 1 {
                // Zeileninhalt in den aktuellen Abschnitt einfügen.
                if numChords == 1 && onlyWhitespaceOrChordComment(elements: currentLineElements) {
                    // Section-Name [abc], einzelner ChordComment (ohne "*") in Zeile entdeckt:
                    
                    // neuen Sectionnamen festlegen
                    var newSectionName = ""
                    if let elem = getFirstChordComment(elements: currentLineElements),
                       case let .chordcomment(comment, _, _) = elem.type {
                        newSectionName = comment
                    }
                    
                    // alte Section abschließen, aber aktuelle Zeile nicht mehr einfügen, da sie nur aus [Section] besteht
                    currentLineElements = []
                    appendLastSection()
                    currentSectionName = newSectionName
                } else if numDirectives == 0 || !onlyWhitespace(elements: currentLineElements) {
                    // Zeile einfügen, falls sie nicht nur aus Directiven (+ evtl. WhiteSpace) besteht
                    currentSectionLines.append(Line(elements: currentLineElements, lineIsColumnBreak: lineIsColumnBreak, lineIsNewPage: lineIsNewPage))
                }
                
                currentLineElements = []
                numDirectives = 0
                numChords = 0
                lineIsColumnBreak = false
                lineIsNewPage = false
            }
            
            position += 1
        }
        
        // Letzten Abschnitt (auch unnamed) hinzufügen
        appendLastSection()
        
        createSplittedLines()
        
        //print(directiveManager.listDirectives())
        return SongRepresentation(sections: sections)
        
        // Hilfsfunktionen
        
        func appendLastSection() {
            if firstTime {
                firstTime = false
                if currentSectionLines.isEmpty && currentLineElements.isEmpty { return }
            }
            
            sections.append(Section(name: currentSectionName, lines: currentSectionLines))
            currentSectionLines = []
        }
        
        func appendCurrentLineElements() {
            if !currentLineElements.isEmpty {
                currentSectionLines.append(Line(elements: currentLineElements, lineIsColumnBreak: lineIsColumnBreak, lineIsNewPage: lineIsNewPage))
                currentLineElements = []
            }
        }
        
        func createSplittedLines() {
            let chordPadding: Double = 3
            
            for section in sections {
                for line in section.lines {
                    if Task.isCancelled { print("cancelled"); return }

                    var nextChordPosition: Double = 0
                    var nextTextPosition: Double = 0
                    var minNextChordPosition: Double = 0
                    
                    var spl = SplittedLine()

                    for elem in line.elements {
                        switch elem.type {
                        case .chord(let chordtxt, _, let len):
                            let position = max(nextChordPosition, minNextChordPosition)
                            let tElem = TextElement(txt: chordtxt, fontOffset: position, background: true)
                            spl.chords.append(tElem)
                            
                            // wenn Chords angezeigt werden, soll sich der Text danach richten
                            if song.showChords {
                                // textFollowsChords == true: Text genau an Chord-Position, wird danach aber evtl. auseinander gezogen
                                // sym !== symLine.symbols.first && txt.isEmpty: Text nur beim ersten Mal genau an Chord-Position, wird danach aber nicht mehr auseinander gezogen (z.B.: [Bb][B][Am]c[A]d[A]e[A][Bb][B][Am]c[A]d[A]e[A])
                                if textFollowsChords || (spl.chords.count == 1 && spl.texts.isEmpty) {
                                    nextTextPosition = position
                                }
                            }
                            
                            nextChordPosition = position + len
                            minNextChordPosition = nextChordPosition + chordPadding
                            
                        case .chordcomment(let comment, let len, _):
                            let position = nextChordPosition
                            let tElem = TextElement(txt: comment, fontOffset: position, background: false)
                            spl.chords.append(tElem)

                            if song.showChords {
                                // siehe oben
                                if textFollowsChords || (spl.chords.count == 1 && spl.texts.isEmpty) {
                                    nextTextPosition = position
                                }
                            }

                            nextChordPosition = position + len
                            minNextChordPosition = nextChordPosition
                            
                        case .text(let txt, let len), .comment(let txt, let len):
                            let tElem = TextElement(txt: txt, fontOffset: nextTextPosition, background: false)
                            spl.texts.append(tElem)

                            // Chordabstand erzeugen, falls Whitespace
                            if txt.trimmingCharacters(in: .whitespaces).count == 0 {
                                nextChordPosition += sizeOfString(string: txt, font: chordf)
                            }
                            
                            // Text direkt hintereinander setzen
                            nextTextPosition += len
                            
                            // wenn Text angezeigt wird, sollen sich die Chords danach richten
                            if (showText) {
                                nextChordPosition = max(nextTextPosition, nextChordPosition)
                            }
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
                        if isWhitespace { spl.texts = [] }
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
    
    private func onlyWhitespaceOrChordComment(elements: [Element]) -> Bool {
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
    
    // Funktion zum Parsen des Akkord-Strings
    public func parseChord(_ chordString: String, convertGerman: Bool = false) -> ParsedChord? {
        let spl = chordString.components(separatedBy: "/")
        if spl.count > 2 { return nil }
        
        var input = spl[0]
        
        var noSlash: Bool = false
        // wegen / in SexteNone
        if spl.count == 2 && (spl[1] == "9" || spl[1] == "11" || spl[1] == "13") {
            input += "/" + spl[1]
            noSlash = true
        }
        
        var hatKreuz = false
        var hatB = false
        
        // konvertieren in internationale Notation
        if convertGerman {
            if input.lowercased() == "b" { hatB = true }
            if input.lowercased() == "h" { input = "b" }
        }
        
        var index = input.startIndex
        
        // Grundton extrahieren
        guard index < input.endIndex, let grundton = Grundton.allCases.first(where: { String(input[index]).lowercased() == $0.rawValue.lowercased() }) else {
            return nil
        }
        index = input.index(after: index)
        
        // Prüfen, ob ein Kreuz (#) oder Be (b) folgt
        if index < input.endIndex {
            if String(input[index]) == Versetzungszeichen.hash.rawValue {
                hatKreuz = true
                index = input.index(after: index)
            } else if String(input[index]) == Versetzungszeichen.b.rawValue {
                hatB = true
                index = input.index(after: index)
            }
        }
        
        // nichtexistente Akkorde
        if ["B#", "E#", "Fb"].contains(grundton.rawValue.uppercased() + (hatKreuz ? Versetzungszeichen.hash.rawValue : (hatB ? Versetzungszeichen.b.rawValue : ""))) {
            return nil
        }
        
        // Folgt ein m für Moll
        var istMoll = false
        if index < input.endIndex {
            if String(input[index]).lowercased() == "m" && !String(input[index...].lowercased()).starts(with: "maj") {
                istMoll = true
                index = input.index(after: index)
            }
        }
        
        var mk: Mehrklang? = nil
        if index < input.endIndex {
            let rest = input[index...]
            mk = Mehrklang.allCases.first { $0.rawValue.lowercased() == String(rest.lowercased()) }
            if mk == nil {
                return nil
            }
        }
        
        // Prüfen auf Slash-Akkord
        var basston: Grundton? = nil
        var basskreuz: Bool = false
        var bassB: Bool = false
        if spl.count == 2 && !noSlash {
            input = spl[1]
            
            if convertGerman {
                if input.lowercased() == "b" { bassB = true }
                if input.lowercased() == "h" { input = "b" }
            }
            
            index = input.startIndex
            
            if index < input.endIndex {
                // Basston bestimmen
                guard index < input.endIndex, let grundton = Grundton.allCases.first(where: { String(input[index]).lowercased() == $0.rawValue.lowercased() }) else {
                    return nil
                }
                basston = grundton
                index = input.index(after: index)
                
                // Optionales Kreuz (#) oder Be (b) für den Basston
                if index < input.endIndex {
                    if String(input[index]) == Versetzungszeichen.hash.rawValue {
                        basskreuz = true
                        index = input.index(after: index)
                    } else if String(input[index]) == Versetzungszeichen.b.rawValue {
                        bassB = true
                        index = input.index(after: index)
                    }
                }
            }

            if index != input.endIndex || basston == nil {
                return nil
            }
        }
        
        // Akkord erstellen und zurückgeben
        return ParsedChord(grundton: grundton, istMoll: istMoll, hatKreuz: hatKreuz, hatB: hatB, mehrklang: mk, basston: basston, bassKreuz: basskreuz, bassB: bassB)
    }
    
    // Ersetzt Variablen durch ihren Wert: %{ variable }
    private func processReplace(viewModel: ViewModel, song: Song, srcline: String) -> String {
        if srcline.isEmpty { return srcline }
        
        var src: String = srcline

        while true {
            let dirRepl = findSubstringBetweenDelimiters(mainString: src, startDelimiter: "%{", endDelimiter: "}")
            
            if dirRepl == nil { break }
            let str = dirRepl!.substring.trimmingCharacters(in: .whitespaces).lowercased()
            let s1Index = dirRepl!.startIndex
            let eIndex = dirRepl!.endIndex
            let sIndex = src.index(s1Index, offsetBy: -2)
            
            var repl: String?
            if str.count < 200 && str.count > 0 {
                if let dirval = directiveManager.getDirective(str) {
                    repl = dirval
                } else {
                    if let special = DirectiveNamesSpecial(rawValue: str) {
                        switch special {
                        case DirectiveNamesSpecial.key_actual:
                            let key = directiveManager.getDirective(DirectiveType.key.rawValue)
                            if let key = key {
                                let chord = parseChord(key)
                                if let chord = chord {
                                    repl = chord.toString(transpose: directiveManager.transpose, convertGerman: viewModel.isGermanNotation)
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
