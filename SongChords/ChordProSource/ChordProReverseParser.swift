//
//  ChordProReverseParser.swift
//  SongChords
//
//  Created by Peter Wichert on 13.11.24.
//

public class ChordProReverseParser: ChordsProBase {
    public override init() { super.init() }

    public func toString(sections: [CPPSection]) -> String {
        var res: String = ""

        for section in sections {
            res.append("[\(section.name)]\n")
            
            for spl in section.splittedLines {
                var split = spl
                res.append(mixSplittedLine(splittedLine: &split) + "\n")
            }
        }
        
        return res
    }
    
    public func parse(input: String) -> [CPPSection] {
        var sections: [CPPSection] = []
        
        var lines = [String]()
        input.enumerateLines{ (line, _) -> () in
            lines.append(line)
        }
        
        var lastLine: (textElement: [TextElement], isChord: Bool)?

        var lastSection: CPPSection?
        var sectionName: String = ""
        var cnt = lines.count
        
        // SplittedLines erzeugen
        
        for line in lines {
            cnt -= 1
            
            let curLine = isChordline(line: line)
            
            if line.starts(with: "[") && line.last == "]" {
                let s = line.index(after: line.startIndex)
                let e = line.index(before: line.endIndex)
                
                if let lastSection = lastSection { sections.append(lastSection) }
                sectionName = String(line[s..<e])
                lastSection = CPPSection(name: sectionName, lines: [])
                
                continue
            }
            
            if curLine.isChord {
                // aktuelle Zeile sind Chords
                if let last = lastLine, last.isChord {
                    // letzte Zeile waren auch Chords, also eine einzelne Chordzeile ohne Text
                    if lastSection == nil { lastSection = CPPSection(name: sectionName, lines: []) }
                    lastSection!.splittedLines.append(SplittedLine(chords: last.textElement))
                }
                // für nächste Zeile merken
                lastLine = curLine
                if cnt == 0 { lastSection!.splittedLines.append(SplittedLine(chords: curLine.textElement)) }
            } else {
                // aktuelle Zeile keine Chords
                if let last = lastLine, last.isChord {
                    // letzte Zeile waren Chords, also komplette Chord/Text-Zeile
                    if lastSection == nil { lastSection = CPPSection(name: sectionName, lines: [])}
                    lastSection!.splittedLines.append(SplittedLine(chords: last.textElement, texts: curLine.textElement))

                    // Text als erledigt merken
                    lastLine = nil
                } else  {
                    // letzte Zeile waren keine Chords, also eine einzelne Textzeile ohne Chord
                    if lastSection == nil { lastSection = CPPSection(name: sectionName, lines: [])}
                    lastSection!.splittedLines.append(SplittedLine(texts: curLine.textElement))
                 
                    // Text als erledigt merken
                    lastLine = nil
                }
            }
        }
        
        if let lastSection = lastSection { sections.append(lastSection) }
        
        return sections
    }
    
    private func isChordline(line: String) -> (textElement: [TextElement], isChord: Bool) {
        let spl = splitWords(line: line)
        
        var chords: [TextElement] = []
        var numChords: Int = 0
        var numTexts: Int = 0
        
        for word in spl {
            if let chord = parseChord(word.txt) {
                chords.append(TextElement(txt: "[" + chord.toString(transpose: 0, convertGerman: false) + "]", fontOffset: Double(word.pos), background: false))
                numChords += 1
            } else {
                chords.append(TextElement(txt: word.txt, fontOffset: Double(word.pos), background: false))
                numTexts += 1
            }
        }
        
        if numChords > 0 && numChords > spl.count / 2 { return (chords, true) }
        return (chords, false)
    }
    
    private func splitWords(line: String) -> [(pos: Int, txt: String)] {
        var res = [(Int, String)]()
        let ar = line.split(separator: " ", omittingEmptySubsequences: false)
        
        var emptyCnt = 0
        var pos = 0

        for i in ar {
            if i.isEmpty {
                emptyCnt += 1
            }
            else {
                pos += emptyCnt
                if res.count > 0 {
                    // emptyCnt und split(): Blanks VOR dem ersten Wort werden ALLE gezählt. Nach dem ersten Wort fehlt immer eines.
                    pos += 1
                }
                
                res.append((pos, String(i)))
                pos += i.count
                emptyCnt = 0
            }
        }
        
        return res
    }
    
    private func mixSplittedLine(splittedLine: inout SplittedLine) -> String {
        var txt = splittedLine.textsToString() ?? ""
        
        // absteigend sortiert
        for chord in splittedLine.chords.sorted(by: { $0.fontOffset > $1.fontOffset }) {
            if Int(chord.fontOffset) > txt.count { txt.append(String(repeating: " ", count: Int(chord.fontOffset) - txt.count)) }
            
            // Chords haben schon [], Texte werden ansonsten hier zum ChordComment mit [* ...]
            let t = (chord.txt.first == "[" && chord.txt.last == "]" ? chord.txt : "[*" + chord.txt + "]")
            txt.insert(contentsOf: t, at: txt.index(txt.startIndex, offsetBy: Int(chord.fontOffset)))
        }
        
        return txt
    }
    
//    private func stringFromSplittedLineText(splittedLine: inout SplittedLine) -> String? {
//        if splittedLine.texts.isEmpty { return nil }
//        
//        var res: String = ""
//        
//        for txt in splittedLine.texts {
//            let pos = Int(txt.fontOffset)
//            if res.count < pos {
//                res.append(String(repeating: " ", count: pos - res.count))
//            }
//            res.append(txt.txt)
//        }
//        
//        return res
//    }
}
