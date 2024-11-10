//
//  Song.swift
//  SongChords Develop
//
//  Created by Peter Wichert on 09.10.24.
//

import Foundation

enum ParserError: Error {
//    case inputTooLarge
}

@Observable
public class SongRepresentation {
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
                    case .chord(let chord, _):
                        result += "[" + chord + "]"
                    case.chordcomment(let comment):
                        result += comment
                    case .text(let text):
                        result += text
                    case .comment(let text):
                        result += text
                    }
                }

                result += "\n"
            }
        }
        
        return result
    }
}

struct Section: Identifiable {
    let id = UUID()
    let name: String
    let lines: [Line]
}

struct Line: Identifiable {
    let id = UUID()
    let elements: [Element]

    let lineIsColumnBreak: Bool
    let lineIsNewPage: Bool
}

struct Element: Identifiable {
    let id = UUID()
    let type: ElementType
}

enum ElementType {    
    case chord(String, ParsedChord)
    case chordcomment(String)
    case comment(String)
    case text(String)
}

public struct ChordProParser {
    private let tokens: [Token]
    private let directiveManager = DirectiveManager()
    
    private let isGermanNotation: Bool = false
    
    public init(tokens: [Token]) {
        self.tokens = tokens
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

        while position < tokens.count {
            let token = tokens[position]
            
            switch token {
            case .curlyEnclosed(let directive):
                numDirectives += 1
                
                if let d = directiveManager.addDirective(processReplace(directive)) {
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
                        currentLineElements.append(Element(type: .comment(val)))
                        
                    default: break
                    }
                } else {
                    currentLineElements.append(Element(type: .text(processReplace(directive))))
                }
                
            case .bracketEnclosed(let chord):
                numChords += 1
                if chord.starts(with: "*") {
                    currentLineElements.append(Element(type: .chordcomment(processReplace(String(chord.dropFirst())))))
                } else {
                    if let pchord = parseChord(chord, convertGerman: isGermanNotation) {
                        currentLineElements.append(Element(type: .chord(chord, pchord)))
                    } else {
                        currentLineElements.append(Element(type: .chordcomment(processReplace(chord))))
                    }
                }
                
            case .text(let text):
                currentLineElements.append(Element(type: .text(processReplace(text))))
                
            case .comment(let text):
                currentLineElements.append(Element(type: .comment(processReplace(text))))
                
            case .newLine: break
                
            }
            
            // neue Zeile oder Ende?
            if .newLine == token || position == tokens.endIndex - 1 {
                // Zeileninhalt in den aktuellen Abschnitt einfügen.
                if numChords == 1 && onlyWhitespaceOrChordComment(elements: currentLineElements) {
                    // Section-Name [abc], einzelner ChordComment in Zeile entdeckt:

                    // neuen Sectionnamen festlegen
                    var newSectionName = ""
                    if let elem = getFirstChordComment(elements: currentLineElements),
                       case let .chordcomment(comment) = elem.type {
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
    }
        
    private func onlyWhitespace(elements: [Element]) -> Bool {
        return elements.allSatisfy { element in
            if case .text(let text) = element.type, text.trimmingCharacters(in: .whitespaces).isEmpty { return true }
            return false
        }
    }
    
    private func onlyWhitespaceOrChordComment(elements: [Element]) -> Bool {
        return elements.allSatisfy { element in
            if case .text(let text) = element.type, text.trimmingCharacters(in: .whitespaces).isEmpty { return true }
            if case .chordcomment(_) = element.type { return true }
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
    private func processReplace(_ srcline: String) -> String {
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
                                    repl = chord.toString(transpose: directiveManager.transpose, convertGerman: isGermanNotation)
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
